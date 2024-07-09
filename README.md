# aix_powerha_facts

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with aix_powerha_facts](#setup)
    * [What aix_powerha_facts affects](#what-aix_powerha_facts-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with aix_powerha_facts](#beginning-with-aix_powerha_facts)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

The cryssoft-aix_powerha_facts module populates the $::facts['aix_powerha'] hash with 
values that are of interest if you're using Puppet to manage AIX systems running IBM's
PowerHA System Mirror product.  It does not include any functionality for configuring
that product yet.

## Setup

Put the module in place in your Puppet master server as usual.  AIX-based systems
will start populating the $::facts['aix_powerha'] hash with their next run, and you
can start referencing those facts in your classes.

### What aix_powerha_facts affects

At this time, the cryssoft-aix_powerha_facts module ONLY supplies custom facts.  It 
does not change anything and should have no side-effects.

### Setup Requirements

As a custom facts module, I believe pluginsync must be enabled for this to work.

### Beginning with aix_powerha_facts

If you're using Puppet Enterprise, the new fact(s) will show up in the PE console
for each AIX-based node under management.  If you're not using Puppet Enterprise,
you'll need to use a different approach to checking for their existence and values.

## Usage

As notes, cryssoft-aix_powerha_facts is only providing custom facts.  Once the module
and its Ruby payload are distributed to your AIX-based nodes, those facts will be
available in your classes.

## Reference

$::facts['aix_powerha'] is the top of a (potentially) large hash of configuration and
run-time data.

## Limitations

This should work on any AIX-based system.  

NOTE:  This module has been tested on AIX 6.1, 7.1, and 7.2 with PowerHA System Mirror 7.1 and 7.2
as well as no-PowerHA code installed.  It has not been tested in a multi-site XD environment, and
the number of test cases and use cases so far has been relatively small.

NOTE:  Updated 2024/07/09 - this module continues to work properly with AIX 7.3 and PowerHA up
through version/service pack 7.2.8.1.  Adding this update as part of re-publishing the module.

## Development

Make suggestions.  Look at the code on github.  Send updates or outputs.  I don't have
a specific set of rules for contributors at this point.

While it won't eliminate the obvious race condition, later version(s) will try to determine
the cluster and resource group state (stable, unstable, changing, etc.) to further reduce
the potential for side-effects of managing Puppet resources in a PowerHA world.

## Release Notes/Contributors/Etc.

Starting with 0.3.0 - Pretty simple stuff.  Not sure if this will ever morph into a
control/configuration module with types/providers/etc. to actually do anything 
meaningful about controlling PowerHA nodes.  I'm not even sure that would be a
good idea.
