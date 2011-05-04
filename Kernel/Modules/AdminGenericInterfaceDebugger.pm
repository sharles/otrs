# --
# Kernel/Modules/AdminGenericInterfaceDebugger.pm - provides a log view for admins
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: AdminGenericInterfaceDebugger.pm,v 1.3 2011-05-04 13:16:59 mg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminGenericInterfaceDebugger;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.3 $) [1];

use Kernel::System::GenericInterface::Webservice;
use Kernel::System::GenericInterface::DebugLog;

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    for (qw(ParamObject LayoutObject LogObject ConfigObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    $Self->{WebserviceObject} = Kernel::System::GenericInterface::Webservice->new( %{$Self} );
    $Self->{DebugLogObject}   = Kernel::System::GenericInterface::DebugLog->new( %{$Self} );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $WebserviceID = $Self->{ParamObject}->GetParam( Param => 'WebserviceID' );
    if ( !$WebserviceID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need WebserviceID!",
        );
    }

    my $WebserviceData = $Self->{WebserviceObject}->WebserviceGet( ID => $WebserviceID );

    if ( !IsHashRefWithData($WebserviceData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for WebserviceID $WebserviceID",
        );
    }

    if ( $Self->{Subaction} eq 'GetRequestList' ) {
        return $Self->_GetRequestList(
            %Param,
            WebserviceID   => $WebserviceID,
            WebserviceData => $WebserviceData,
        );
    }
    elsif ( $Self->{Subaction} eq 'GetCommunicationDetails' ) {
        return $Self->_GetCommunicationDetails(
            %Param,
            WebserviceID   => $WebserviceID,
            WebserviceData => $WebserviceData,
        );
    }

    # default: show start screen
    return $Self->_ShowScreen(
        %Param,
        WebserviceID   => $WebserviceID,
        WebserviceData => $WebserviceData,
    );
}

sub _ShowScreen {
    my ( $Self, %Param ) = @_;

    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    my $FilterTypeStrg = $Self->{LayoutObject}->BuildSelection(
        Data => [
            'Provider',
            'Requester',
        ],
        Name         => 'FilterType',
        PossibleNone => 1,
        Translate    => 0,
    );

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminGenericInterfaceDebugger',
        Data         => {
            %Param,
            WebserviceName => $Param{WebserviceData}->{Name},
            FilterTypeStrg => $FilterTypeStrg,
        },
    );
    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

sub _GetRequestList {
    my ( $Self, %Param ) = @_;

    my %LogSearchParam = (
        WebserviceID => $Param{WebserviceID},
    );

    my $FilterType = $Self->{ParamObject}->GetParam( Param => 'FilterType' );
    $LogSearchParam{CommunicationType} = $FilterType if ($FilterType);

    my $FilterRemoteIP = $Self->{ParamObject}->GetParam( Param => 'FilterRemoteIP' );
    $LogSearchParam{RemoteIP} = $FilterRemoteIP
        if ( $FilterRemoteIP && IsIPv4Address($FilterRemoteIP) );

    my $LogData = $Self->{DebugLogObject}->LogSearch(
        %LogSearchParam,

        #            CommunicationType => 'Provider',     # optional, 'Provider' or 'Requester'
        #            CreatedAtOrAfter  => '2011-01-01 00:00:00', # optional
        #            CreatedArOrBefore => '2011-12-31 23:59:59', # optional
    );

    # Fail gracefully
    $LogData = [] if ( !$LogData );

    # build JSON output
    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => {
            LogData => $LogData,
        },
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _GetCommunicationDetails {
    my ( $Self, %Param ) = @_;

    my $CommunicationID = $Self->{ParamObject}->GetParam( Param => 'CommunicationID' );

    if ( !$CommunicationID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Got no CommunicationID',
        );

        return;    # return empty response
    }

    my $LogData = $Self->{DebugLogObject}->LogGetWithData(
        WebserviceID    => $Param{WebserviceID},
        CommunicationID => $CommunicationID,
    );

    # build JSON output
    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => {
            LogData => $LogData,
        },
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;