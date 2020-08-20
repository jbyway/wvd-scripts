# The scripts included here for Custom RDP Settings and Remote App publishing are intended for WVD Classic (non-ARM) environments and haven't been modified yet to support the July 2020 Update that natively supports ARM environments. For Remote Apps check out the built in ability to publish directly from the portal. 


# wvd-scripts
Scripts I've created to assist with Windows Virtual Desktop - this is my own work and is not officially supported by Microsoft. 

Scripts may require the use of Powershell ISE to run correctly (particularly when using out-gridview). 


# Set-WVDCustomRDPSettings.ps1 requires # CustomRDPPropertyValues.json
Use the json file as your configuration values and only update the "ConfiguredValue" field, using ther other fields to determine the required settings and/or descriptions on what each does. Further details are available in the ps1 script description notes. 
