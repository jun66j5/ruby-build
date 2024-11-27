$workspace = $Env:GITHUB_WORKSPACE
$ProgramFiles = $Env:ProgramFiles
$arch = $Env:ARCH
$triplet = "$arch-windows"

Write-Output "::group::env"
Get-ChildItem env:
switch -Exact ($arch) {
    'x64' {
        $rubyarch = 'x64-mswin64'
        $ucrtbase = 'C:\Windows\system32\ucrtbase.dll'
    }
    'x86' {
        $rubyarch = 'mswin32'
        $ucrtbase = 'C:\Windows\SysWOW64\ucrtbase.dll'
    }
}
Write-Output "::group::ucrtbase.dll"
Get-Command $ucrtbase | Format-List
Write-Output '::endgroup::'

Write-Output "::group::vcpkg install"
vcpkg --triplet $triplet install `
    libxml2 libxslt openssl readline zlib libyaml libffi
Write-Output '::endgroup::'
if ($LASTEXITCODE) {
    Write-Error "vcpkg exited with $LASTEXITCODE"
    exit 1
}
$vcpkg_dir = "$($Env:VCPKG_INSTALLATION_ROOT)\installed\$arch-windows"

$Env:PATH = "$vcpkg_dir\bin;$($Env:PATH)"
$opt_dir = $vcpkg_dir.replace('\', '/')
$ruby_versions = $Env:RUBY_VERSIONS -Split ' '
foreach ($version in $ruby_versions) {
    Write-Output "::group::Build ruby $version"
    $arcfile = "$workspace\ruby-$version.tar.gz"
    $version -match '^\d+\.\d+'
    $major, $minor = $matches[0].Split('.')
    $arcurl = "https://cache.ruby-lang.org/pub/ruby/$($matches[0])/ruby-$version.tar.gz"
    Invoke-WebRequest -Uri $arcurl -OutFile $arcfile
    & tar xzf $arcfile -C $workspace
    Set-Location -LiteralPath "$workspace\ruby-$version"
    $basename = "ruby-$version-$rubyarch"
    $prefix = "C:\$basename"
    & 'C:\Program Files\Git\usr\bin\sed.exe' `
        -i -e 's|^WARNFLAGS = -W2 |WARNFLAGS = -W3 |' `
        win32\Makefile.sub
    $configure_args = @("--prefix=$($prefix.replace('\', '/'))",
                        "--with-opt-dir=$opt_dir")
    if ((($major -gt 3) -or ($major -ge 3) -and ($minor -ge 4)) -and
        (Select-String -Path win32\Makefile.sub -Quiet '^NTVER = 0x0600$'))
    {
        $configure_args += '--with-ntver=0x0602'
    }
    Write-Output "Run win32\configure.bat with $configure_args"
    & win32\configure.bat $configure_args
    if ($LASTEXITCODE) {
        Write-Error "win32\configure.bat exited with $LASTEXITCODE"
        exit 1
    }
    & nmake -nologo all install-nodoc
    if ($LASTEXITCODE) {
        Write-Error "nmake exited with $LASTEXITCODE"
        exit 1
    }
    Copy-Item -Path "$vcpkg_dir\bin\*.dll" -Destination "$prefix\bin"
    Set-Location -LiteralPath C:\
    & "$ProgramFiles\7-Zip\7z" a "$workspace\$basename.7z" `
                               "$($prefix.replace('C:\', ''))"
    if ($LASTEXITCODE) {
        Write-Error "7z exited with $LASTEXITCODE"
        exit 1
    }
    Write-Output '::endgroup::'
}
