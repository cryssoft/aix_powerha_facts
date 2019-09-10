#
#  FACT(S):	aix_powerha
#
#  PURPOSE:	This custom fact returns a complex hash of information about
#		whether IBM's PowerHA is installed on an AIX system, and if
#		so, how it is configured and operating.  It doesn't dive as
#		deeply as it might, especially in areas where we don't have
#		licensing or an active configuration.
#
#  RETURNS:	(hash)
#
#  AUTHOR:	Christopher Petersen, Magellan Health
#
#  DATE:	June 18, 2018 - June 27, 2018
#
#  NOTES:	Myriad names and acronyms are trademarked or copyrighted by IBM
#		including but not limited to IBM, PowerHA, AIX, RSCT (Reliable,
#		Scalable Cluster Technology), and CAA (Cluster-Aware AIX).  All
#		rights to such names and acronyms belong with their owner.
#
#		The output formats of all of the PowerHA utilities and some of
#		the AIX utilities called from this module are subject to change
#		without warning.
#
#-------------------------------------------------------------------------------
#
#  LAST MOD:	July 5, 2018
#
#  MODIFICATION HISTORY:
#
#  2018/07/05 - cp - Fixed the logic for the determination of PowerHA node name
#		since it was still picking up the host name/interface name.
#
#-------------------------------------------------------------------------------
#
Facter.add(:aix_powerha) do
    #  The basics will be different for AIX versus Linux or other OSs
    confine :osfamily => 'AIX'

    #  Capture the installation status and version if it's there
    setcode do
        #  Default the basics for our hash and other uses
        l_powerhaUtilsDir = '/usr/es/sbin/cluster/utilities'
        l_powerhaVersion  = nil
        #
        l_headerList      = []
        l_splitFields     = ["disk", "volume_group", "concurrent_volume_group", "filesystem", "export_filesystem", \
                             "shared_tape_resources", "aix_connections_services", "aix_fast_connect_services", \
                             "communication_links", "applications", "mount_filesystem", "service_label", "nfs_network", \
                             "node_priority_policy", "nodes", "gmd_rep_resource", "pprc_rep_resource", "ercmf_rep_resource", \
                             "sr_rep_resource", "tc_rep_resource", "genxd_rep_resource", "svcpprc_rep_resource", \
                             "gmvg_rep_resource", "primarynodes", "secondarynodes", "export_filesystem_v4", "stable_storage_path", \
                             "userdefined_resources", "raw_disk"]
        #
        l_powerhaHash     = {}

        #  Look for the PowerHA "server" package information ### FORMAT-DEPENDENT
        l_lines = Facter::Util::Resolution.exec('/bin/lslpp -lc cluster.es.server.rte 2>/dev/null')

        l_lines && l_lines.split("\n").each do |l_oneLine|
            next if l_oneLine =~ /^#/
            l_powerhaVersion = l_oneLine.split(":")[2]
        end

        #  If we have a version, then the software is installed and we carry on
        if l_powerhaVersion != nil
            #  Default/define the scalar contents of the hash
            l_powerhaHash['installed']      = true
            l_powerhaHash['any_rg_active']  = false
            l_powerhaHash['version']        = l_powerhaVersion
            l_powerhaHash['cluster_id']     = nil
            l_powerhaHash['cluster_name']   = nil
            l_powerhaHash['node_name']      = nil
            l_powerhaHash['repo_disk']      = nil
            l_powerhaHash['snmp_community'] = nil
            #  Default/define the non-scalar contents of the hash
            l_powerhaHash['active_rgs']     = []
            l_powerhaHash['app_hash']       = {}
            l_powerhaHash['daemon_hash']    = {}
            l_powerhaHash['network_hash']   = {}
            l_powerhaHash['node_hash']      = {}
            l_powerhaHash['rg_hash']        = {}
            l_powerhaHash['site_hash']      = {}

            #  Set the PowerHA "architecture" based on major version
            case l_powerhaVersion
                when /^6/
                    l_powerhaHash['architecture'] = 'RSCT'
                when /^7/
                    l_powerhaHash['architecture'] = 'CAA'
                else
                    l_powerhaHash['architecture'] = 'UNKNOWN'
            end

            #  Look for the cluster ID, name, and possibly the PowerHA 7/CAA repository disk ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllsclstr -c 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_powerhaHash['cluster_id']    = l_oneLine.split(":")[0]
                l_powerhaHash['cluster_name']  = l_oneLine.split(":")[1]
                if l_powerhaVersion =~ /^7/
                    l_powerhaHash['repo_disk'] = l_oneLine.split(":")[4]
                end
            end

            #  Look for the SNMP community string we're using for status inqueries ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cl_community_name 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_powerhaHash['snmp_community'] = l_oneLine.split(" ")[1]
            end

            #  Ask the system resource controller for the list of PowerHA-related daemons running ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec('/bin/lssrc -g cluster 2>/dev/null')

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^Subsystem/
                l_subsysName = l_oneLine.split(" ")[0]
                l_processID  = l_oneLine.split(" ")[2]
                l_powerhaHash['daemon_hash'][l_subsysName] = l_processID
            end

            #  Get information about the "sites" defined for this PowerHA cluster ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllssite -c 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_siteFields = l_oneLine.split(":")
                l_powerhaHash['site_hash'][l_siteFields[0]]               = {}
                l_powerhaHash['site_hash'][l_siteFields[0]]['sitenodes']  = l_siteFields[1]
                l_powerhaHash['site_hash'][l_siteFields[0]]['dominance']  = l_siteFields[2]
                l_powerhaHash['site_hash'][l_siteFields[0]]['protection'] = l_siteFields[3]
                l_powerhaHash['site_hash'][l_siteFields[0]]['prio']       = l_siteFields[4]
                l_powerhaHash['site_hash'][l_siteFields[0]]['hmcs']       = l_siteFields[5]
            end

            #  Get information about the "networks" defined for this PowerHA cluster ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllsnw -c 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_nwFields = l_oneLine.split(":")
                l_powerhaHash['network_hash'][l_nwFields[0]]                   = {}
                l_powerhaHash['network_hash'][l_nwFields[0]]['attr']           = l_nwFields[1]
                l_powerhaHash['network_hash'][l_nwFields[0]]['alias']          = l_nwFields[2]
                l_powerhaHash['network_hash'][l_nwFields[0]]['monitor_method'] = l_nwFields[3]
                #
                #  We're going to explicitly ignore the rest of the fields in these records.  The header line doesn't
                #  match the data, and the data is more or less available under the 'cllsnode -c' output anyway.
                #
            end

            #  Get information about the "nodes" defined for this PowerHA cluster ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllsnode -c 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_nodeFields = l_oneLine.split(":")
                l_powerhaHash['node_hash'][l_nodeFields[0]] = {}
                l_ctr = 1
                while l_ctr < l_nodeFields.length do
                    if l_powerhaHash['node_hash'][l_nodeFields[0]].has_key?(l_nodeFields[l_ctr + 2]) == false
                        l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]               = {}
                        l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['if_type']    = l_nodeFields[l_ctr + 3]
                        l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['visibility'] = l_nodeFields[l_ctr + 4]
                        l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['roles']      = {}
                    end
                    if l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['roles'].has_key?(l_nodeFields[l_ctr + 1]) == false
                        l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['roles'][l_nodeFields[l_ctr + 1]] = {}
                    end
                    l_powerhaHash['node_hash'][l_nodeFields[0]][l_nodeFields[l_ctr + 2]]['roles'][l_nodeFields[l_ctr + 1]][l_nodeFields[l_ctr]] = l_nodeFields[l_ctr + 5]
                    if l_nodeFields[l_ctr] == Facter.value('hostname') || l_nodeFields[l_ctr] == Facter.value('fqdn')
                        l_powerhaHash['node_name'] = l_nodeFields[0]
                    end
                    #####  Another instance where the header fields don't match the data.  WTF IBM?
                    if l_nodeFields[l_ctr + 1] == "service"
                        l_ctr = l_ctr + 7
                    else
                        l_ctr = l_ctr + 6
                    end
                end
            end

            #
            #  Get information about the resource groups and their status - use the awk to get around bizarre, 
            #  non-ASCII characters in some PowerHA 7 outputs that make ruby and/or facter unhappy. ### FORMAT-DEPENDENT
            #
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/clRGinfo -c 2>/dev/null | /bin/awk -F: '{ printf(\"%s:%s:%s:%s:%s:%s:%s\\n\",$1,$2,$3,$4,$5,$6,$7); }' ")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^clRGinfo:/
                l_rgFields = l_oneLine.split(":")
                if l_powerhaHash['rg_hash'].has_key?(l_rgFields[0])
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['node_hash'][l_rgFields[2]] = l_rgFields[1]
                else
                    #  Save what we've got so far - either in the RG or the RG/node sub-hash
                    l_powerhaHash['rg_hash'][l_rgFields[0]]                             = {}
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['type']                     = l_rgFields[3]
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['online_where']             = l_rgFields[4]
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['failover_to']              = l_rgFields[5]
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['fallback_when']            = l_rgFields[6]
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['node_hash']                = {}
                    l_powerhaHash['rg_hash'][l_rgFields[0]]['node_hash'][l_rgFields[2]] = l_rgFields[1]

                    #  Loop over some 'cllsres' output for this RG to fill in lots more hash fields ### NOT VERY FORMAT-DEPENDENT
                    l_lines2 = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllsres -c -g #{l_rgFields[0]} 2>/dev/null")

                    l_lines2 && l_lines2.split("\n").each do |l_oneLine2|
                        l_ctr = 0
                        #  Build a list of header field names
                        if l_oneLine2 =~ /^#/
                            l_oneLine2.split(":").each do |l_header|
                                if l_ctr == 0
                                    l_headerList[l_ctr] = l_header[1..-1].downcase
                                else
                                    l_headerList[l_ctr] = l_header.downcase
                                end
                                l_ctr = l_ctr + 1
                            end
                        #  Use the list of header field names to populate more hash keys
                        else
                            l_oneLine2.split(":").each do |l_data|
                                #  This could require some maintenance - split some fields into arrays where valuable
                                if l_splitFields.include?(l_headerList[l_ctr])
                                    l_powerhaHash['rg_hash'][l_rgFields[0]][l_headerList[l_ctr]] = l_data.split(" ")
                                else
                                    l_powerhaHash['rg_hash'][l_rgFields[0]][l_headerList[l_ctr]] = l_data
                                end
                                l_ctr = l_ctr + 1
                            end
                        end
                    end
                end

                if (l_rgFields[2] == Facter.value('hostname') || l_rgFields[2] == Facter.value('fqdn') || l_rgFields[2] == l_powerhaHash['node_name']) && l_rgFields[1] == 'ONLINE'
                    l_powerhaHash['any_rg_active'] = true
                    l_powerhaHash['active_rgs'] << l_rgFields[0]
                end
            end

            #  Get information about the "applications" defined for this PowerHA cluster ### FORMAT-DEPENDENT
            l_lines = Facter::Util::Resolution.exec("#{l_powerhaUtilsDir}/cllsserv -c 2>/dev/null")

            l_lines && l_lines.split("\n").each do |l_oneLine|
                next if l_oneLine =~ /^#/
                l_servFields = l_oneLine.split(":")
                l_powerhaHash['app_hash'][l_servFields[0]]                  = {}
                l_powerhaHash['app_hash'][l_servFields[0]]['start_script']  = l_servFields[1]
                l_powerhaHash['app_hash'][l_servFields[0]]['stop_script']   = l_servFields[2]
                if l_powerhaVersion =~ /^7/
                    l_powerhaHash['app_hash'][l_servFields[0]]['fore_back'] = l_servFields[3]
                    l_powerhaHash['app_hash'][l_servFields[0]]['monitor']   = l_servFields[4]
                end
            end

        #  No version means no PowerHA stuff is possible
        else
            l_powerhaHash['installed'] = false
        end

        #  Implicitly return the hash with its contents
        l_powerhaHash
    end
end
