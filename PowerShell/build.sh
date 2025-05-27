#!/bin/bash
pwsh <<__EOF__
Import-Module ./build.psm1 -ArgumentList \$true
Start-PSBuild -UseNuGetOrg
__EOF__
