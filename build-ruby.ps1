$workspace = $Env:GITHUB_WORKSPACE
$ProgramFiles = $Env:ProgramFiles
$arch = $Env:ARCH
$triplet = "$arch-windows"

Write-Output "::group::vcpkg install"
vcpkg --triplet $triplet install `
    libxml2 libxslt openssl readline zlib libyaml libffi
Write-Output '::endgroup::'
if ($LASTEXITCODE) {
    Write-Error "vcpkg exited with $LASTEXITCODE"
    exit 1
}
$vcpkg_dir = "$($Env:VCPKG_INSTALLATION_ROOT)\installed\$arch-windows"

switch -Exact ($arch) {
    'x64' {
        $rubyarch = 'x64-mswin64'
    }
    'x86' {
        $rubyarch = 'mswin32'
    }
}

$Env:PATH = "$vcpkg_dir\bin;$($Env:PATH)"
$opt_dir = $vcpkg_dir.replace('\', '/')
$ruby_versions = $Env:RUBY_VERSIONS -Split ' '
foreach ($version in $ruby_versions) {
    Write-Output "::group::Build ruby $version"
    $arcfile = "$workspace\ruby-$version.tar.gz"
    $version -match '^\d+\.\d+'
    $arcurl = "https://cache.ruby-lang.org/pub/ruby/$($matches[0])/ruby-$version.tar.gz"
    Invoke-WebRequest -Uri $arcurl -OutFile $arcfile
    & tar xzf $arcfile -C $workspace
    Set-Location -LiteralPath "$workspace\ruby-$version"
    $basename = "ruby-$version-$rubyarch"
    $prefix = "C:\$basename"
    & win32\configure.bat "--prefix=$($prefix.replace('\', '/'))" `
                          "--with-opt-dir=$opt_dir"
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
