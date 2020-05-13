A sample group of custom roles that can be used to help assign permissions against the new ARM Update for Windows Virtual Desktop (May 2020). 

You'll need to replace the {SubscriptionId} with your subscription ID when importing these roles. 

These roles should be assigned to a user at the Azure Resource Group level where the WVD resources reside (Workspace/Hosts etc). 

You will also need to assign a minimum of Reader permissions to the Resource Group in Azure to allow the users assigned this role access to view/update objects. 
