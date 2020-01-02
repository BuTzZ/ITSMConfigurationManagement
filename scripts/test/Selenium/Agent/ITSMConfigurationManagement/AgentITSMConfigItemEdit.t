# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper               = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
        my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

        my @Test = (
            {
                ConfigItemClass => 'Computer',
                CheckEditFields => [
                    'Name', 'DeplStateID', 'InciStateID', 'Vendor', 'Model', 'Description', 'Type', 'Owner',
                    'SerialNumber',
                    'OperatingSystem', 'CPU', 'Ram', 'HardDisk', 'Capacity', 'FQDN', 'NIC', 'PoverDHCP',
                    'GraphicAdapter',
                    'OtherEquipment', 'WarrantyExpirationDate', 'InstallDate', 'Note', 'FileUpload', 'SubmitSave'
                ],
            },
            {
                ConfigItemClass => 'Hardware',
                CheckEditFields => [
                    'Name', 'DeplStateID', 'InciStateID', 'Vendor', 'Model', 'Description', 'Type', 'Owner',
                    'SerialNumber',
                    'WarrantyExpirationDate', 'InstallDate', 'Note', 'FileUpload', 'SubmitSave'
                ],
            },
            {
                ConfigItemClass => 'Location',
                CheckEditFields => [
                    'Name', 'DeplStateID', 'InciStateID', 'Type', 'Phone1', 'Phone2', 'Fax', 'E-Mail', 'Address',
                    'Note', 'FileUpload', 'SubmitSave'
                ],
            },
            {
                ConfigItemClass => 'Network',
                CheckEditFields => [
                    'Name', 'DeplStateID', 'InciStateID', 'Description', 'Type', 'NetworkAddress', 'SubnetMask',
                    'Gateway',
                    'Note', 'FileUpload', 'SubmitSave'
                ],
            },
            {
                ConfigItemClass => 'Software',
                CheckEditFields => [
                    'Name', 'DeplStateID', 'InciStateID', 'Vendor', 'Version', 'Description', 'Type', 'Owner',
                    'SerialNumber',
                    'LicenceType', 'LicenceKey', 'Media', 'Note', 'SubmitSave'
                ],
            },
        );

        # Get 'Production' deployment state ID.
        my $DeplStateDataRef = $GeneralCatalogObject->ItemGet(
            Class => 'ITSM::ConfigItem::DeploymentState',
            Name  => 'Production',
        );
        my $DeplStateID = $DeplStateDataRef->{ItemID};

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'itsm-configitem' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');
        my $RandomID    = $Helper->GetRandomID();

        for my $ConfigItemEdit (@Test) {

            # Navigate to AgentITSMConfigItemAdd screen.
            $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentITSMConfigItemAdd");

            # Get ConfigItem class ID.
            my $ConfigItemDataRef = $GeneralCatalogObject->ItemGet(
                Class => 'ITSM::ConfigItem::Class',
                Name  => $ConfigItemEdit->{ConfigItemClass},
            );
            my $ConfigItemClassID = $ConfigItemDataRef->{ItemID};

            $Selenium->WaitFor(
                JavaScript =>
                    "return typeof(\$) === 'function' && \$('a[href*=\"Action=AgentITSMConfigItemEdit;ClassID=$ConfigItemClassID\"]').length"
            );

            # Click on ConfigItem class.
            $Selenium->find_element(
                "//a[contains(\@href, \'Action=AgentITSMConfigItemEdit;ClassID=$ConfigItemClassID\' )]"
            )->VerifiedClick();

            $Selenium->WaitFor(
                JavaScript => "return typeof(\$) === 'function' && \$('#Name').length && \$('#SubmitButton').length"
            );

            # Check for ConfigItemEdit fields.
            for my $CheckConfigItemField ( @{ $ConfigItemEdit->{CheckEditFields} } ) {

                my $Element = $Selenium->find_element("//*[contains(\@name, \'$CheckConfigItemField\' )]");
                $Element->is_enabled();
                $Element->is_displayed();
            }

            # Create test ConfigItem.
            my $ConfigItemName = $ConfigItemEdit->{ConfigItemClass} . $RandomID;
            $Selenium->find_element( "#Name", 'css' )->send_keys($ConfigItemName);

            $Selenium->execute_script(
                "\$('#DeplStateID').val('$DeplStateID').trigger('redraw.InputField').trigger('change')"
            );
            $Selenium->WaitFor(
                JavaScript => "return typeof(\$) === 'function' && \$('#DeplStateID').val() === '$DeplStateID'"
            );

            $Selenium->execute_script("\$('#InciStateID').val('1').trigger('redraw.InputField').trigger('change')");
            $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#InciStateID').val() === '1'" );

            if ( $ConfigItemEdit->{ConfigItemClass} eq 'Computer' ) {

                # Get General Catalog ID for 'Yes'.
                my $YesDataRef = $GeneralCatalogObject->ItemGet(
                    Class => 'ITSM::ConfigItem::YesNo',
                    Name  => 'Yes',
                );
                my $YesID = $YesDataRef->{ItemID};

                # Enter NIC name.
                $Selenium->find_element("//*[contains(\@name, \'NIC::1\' )]")->send_keys('SeleniumNetwork');

                # Select Yes for DHCPOverIP.
                $Selenium->execute_script(
                    "\$('#' + Core.App.EscapeSelector('Item1NIC::11')).val('$YesID').trigger('redraw.InputField').trigger('change');"
                );
            }
            if ( $ConfigItemEdit->{ConfigItemClass} eq 'Network' ) {
                $Selenium->find_element("//*[contains(\@name, \'NetworkAddress\' )]")->send_keys('SeleniumNetwork');
            }

            $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->VerifiedClick();

            $Selenium->WaitFor(
                JavaScript => "return typeof(\$) === 'function' && \$('h1:contains($ConfigItemName)').length"
            );

            # Get ConfigItem value.
            my @ConfigItemValues = (
                {
                    Value       => $ConfigItemName,
                    Check       => "h1:contains($ConfigItemName)",
                    CheckResult => 1,
                },
                {
                    Value       => $ConfigItemEdit->{ConfigItemClass},
                    Check       => "p.Value:contains($ConfigItemEdit->{ConfigItemClass})",
                    CheckResult => 2,
                },
            );

            # Check submitted values in AgentITSMConfigItemZoom screen.
            for my $CheckConfigItemValue (@ConfigItemValues) {
                $Self->True(
                    $Selenium->execute_script(
                        "return \$('$CheckConfigItemValue->{Check}').length === $CheckConfigItemValue->{CheckResult}"
                    ),
                    "Test ConfigItem value $CheckConfigItemValue->{Value} - found",
                );
            }

            # Get ConfigItemID.
            my $ConfigItemID = $ConfigItemObject->VersionSearch(
                Name => $ConfigItemName
            );

            # Delete created test ConfigItem.
            my $Success = $ConfigItemObject->ConfigItemDelete(
                ConfigItemID => $ConfigItemID->[0],
                UserID       => 1,
            );
            $Self->True(
                $Success,
                "ConfigItem is deleted - ID $ConfigItemID->[0]",
            );
        }
    }
);

1;
