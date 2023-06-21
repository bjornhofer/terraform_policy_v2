locals {
  testmode = true
}
locals {
  folderstructure = [for folder in fileset(path.module, "**") : folder
  if(length(regexall("(\\.json)", folder)) > 0)]
  folders = distinct(flatten([for folder in local.folderstructure : join("/", slice(split("/", folder), 0, length(split("/", folder)) - 1))]))
}

locals {
  // Management Group Settings
  management_group_policy_file_name = "policies.json"
  mgmt_grp_layer0_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 1] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer1_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 2] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer2_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 3] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer3_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 4] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer4_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 5] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer5_policies          = { for folder in [for layers in local.folders : layers if length(split("/", layers)) == 6] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  // Test to iterate only over the first layers
  unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies)
  //unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies, local.mgmt_grp_layer2_policies, local.mgmt_grp_layer3_policies, local.mgmt_grp_layer4_policies, local.mgmt_grp_layer5_policies)
  
  mgmt_grp_policies_temp = { for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => { for policy_name, policy_information in policydata : policy_name => policy_information if try(policy_information.project_name, false) != false } if length(policydata) > 0 }
  ccoe_mgmt_grp_policies_temp = { for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => { for policy_name, policy_information in policydata : policy_name => policy_information if try(policy_information.project_name, false) == false } if length(policydata) > 0 }

  mgmt_grp_policies = merge([ 
    for mgmt_grp, policydata in local.mgmt_grp_policies_temp : 
      { for policy_information in policydata : 
        "${mgmt_grp}/${policy_information.policy_name}" => policy_information 
      } if length(policydata) > 0
    ]...)
  ccoe_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.ccoe_mgmt_grp_policies_temp : 
      { for policy_information in policydata : 
        "${mgmt_grp}/${policy_information.policy_name}" => policy_information 
      } if length(policydata) > 0
    ]...)
}

output "mgmt_grp_policies" {
  value = local.testmode ? local.mgmt_grp_policies : null
}

output "ccoe_mgmt_group_policies" {
  value = local.testmode ? local.ccoe_mgmt_grp_policies : null
}


data "azuredevops_project" "project" {
  for_each = local.mgmt_grp_policies
  name = each.value.project_name
}

output "project" {
  value = local.testmode ? data.azuredevops_project.project : null
}

data "azuredevops_git_repository" "repo" {
  for_each   = local.mgmt_grp_policies
  project_id = data.azuredevops_project.project[each.key].id
  name       = each.value.repo_name
}

output "repo" {
  value = local.testmode ? data.azuredevops_git_repository.repo : null
}

// Bypass missing size increase of devops data source
resource "random_string" "trigger" {
  keepers = {
    timestamp = timestamp()
  }
  length           = 5
  special          = false
}

  locals {
    is_linux = length(regexall("/home/", lower(abspath(path.root)))) > 0
  }

resource "null_resource" "remove_cloned_directory" {
  for_each = local.mgmt_grp_policies

  triggers = {
    string = random_string.trigger.result
  }

  provisioner "local-exec" {
     command = (
      fileexists("${each.value.name}") ?
        local.is_linux ? 
          "rm -rf ${each.value.name}" :
          "rmdir /s /q ${each.value.name}" :
        local.is_linux ? 
          "mkdir -p /policies/${each.key}" :
          "mkdir /policies/${each.key}"
     )
  }
  depends_on = [ random_string.trigger ]
}

resource "null_resource" "git_clone" {
  for_each = local.mgmt_grp_policies

  triggers = {
    string = random_string.trigger.result
  }

  provisioner "local-exec" {
    command = (
      "git clone ${replace(data.azuredevops_git_repository.repo[each.key].web_url, "https://", "https://${local.git_pat}@")} /policies/${each.key}" 
    )
  }

  depends_on = [
    data.azuredevops_git_repository.repo,
    random_string.trigger,
    null_resource.remove_cloned_directory
  ]
}

//merge the mgmt_grp_policies and ccoe_mgmt_grp_policies to one map
locals {
  all_mgmt_grp_policies = merge(local.mgmt_grp_policies, local.ccoe_mgmt_grp_policies)
}

output "all_mgmt_grp_policies" {
  value = local.testmode ? local.all_mgmt_grp_policies : null
}
