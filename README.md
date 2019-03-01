# universal-dashboard-packages
Packages for Universal Dashboard

# About

This repo will contain modules providing functionality for [Universal Dashboard](https://github.com/ironmansoftware/universal-dashboard)

# How-to

If used with [Universal Dashboard Bootstrap](https://github.com/al-ign/universal-dashboard-bootstrap) place the package folder to the `Pages`, it will be automatically added

If used with default Universal Dashboard load with 

	Get-ChildItem $pathToThePackageFolder -Recurse -Filter *.ps1 | Sort-Object Name | % {
		Write-Host "Loading UD page: $($_.FullName)"
		. $_.FullName
		}

# vSphere package

This package was designed for a IaaS provider as a way to quickly search VMs and to provide some additional diagnostic information.
