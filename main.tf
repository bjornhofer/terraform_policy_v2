// Verbosity for all possible resources blocks
locals {
  verbose = false
}

locals {
  folderstructure_policies = [for folder in fileset(path.module, "**") : folder
  if(length(regexall("(\\.json)", folder)) > 0)]
  folders_policies = distinct(flatten([for folder in local.folderstructure_policies : join("/", slice(split("/", folder), 0, length(split("/", folder)) - 1))]))
}

locals {
  // Management Group Settings
  management_group_policy_file_name = "policies.json"
  mgmt_grp_layer0_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 1] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer1_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 2] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer2_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 3] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer3_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 4] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer4_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 5] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  mgmt_grp_layer5_policies          = { for folder in [for layers in local.folders_policies : layers if length(split("/", layers)) == 6] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_policy_file_name}")), {}) }
  // Test to iterate only over the first two layers
  //unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies)
  unfiltered_mgmt_grp_policies = merge(local.mgmt_grp_layer0_policies, local.mgmt_grp_layer1_policies, local.mgmt_grp_layer2_policies, local.mgmt_grp_layer3_policies, local.mgmt_grp_layer4_policies, local.mgmt_grp_layer5_policies)
  


  // Filter the policies (remove empty entries in map)
  // File based policy definition
  filebased_mgmt_grp_policies_temp = {
    for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => {
      for policy_name, policy_information in policydata :
      policy_name => policy_information
      if try(policy_information.project_name, false) == false &&
    try(policy_information.policy_definition_id, false) == false }
  if length(policydata) > 0 }

  // BuiltIn policy definition
  builtin_mgmt_grp_policies_temp = {
    for mgmt_grp, policydata in local.unfiltered_mgmt_grp_policies : mgmt_grp => {
      for policy_name, policy_information in policydata :
      policy_name => policy_information
      if try(policy_information.project_name, false) == false &&
    try(policy_information.policy_definition_id, false) != false }
  if length(policydata) > 0 }

  // Build final policy map
  // File based policy definition
  filebased_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.filebased_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${policy_information.policy_filename}" => policy_information
    } if length(policydata) > 0
  ]...)

  // BuiltIn policy definition
  builtin_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.builtin_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${policy_information.policy_filename}" => policy_information
    } if length(policydata) > 0
  ]...)

}

output "filebased_mgmt_grp_policies" {
  value = local.verbose ? local.filebased_mgmt_grp_policies : null
}
output "builtin_mgmt_grp_policies" {
  value = local.verbose ? local.builtin_mgmt_grp_policies : null
}

// Deploy policiy defintions
// only if variable deploy_custom_policies is set to true
resource "azurerm_policy_definition" "filebased" {
  for_each            = var.deploy_policies ? local.filebased_mgmt_grp_policies : {}
  name                = try(each.value.definition_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name        = try(each.value.definition_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"])
  description         = try(each.value.definition_description, jsondecode(file("${path.module}/${each.key}"))["properties"]["description"])
  policy_type         = jsondecode(file("${path.module}/${each.key}"))["properties"]["policyType"]
  mode                = jsondecode(file("${path.module}/${each.key}"))["properties"]["mode"]
  policy_rule         = jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["policyRule"])
  management_group_id = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
}

locals {
  test = {
    for policy_name, policy_data in local.filebased_mgmt_grp_policies : policy_name => policy_data 
      if try(policy_data.assign_to_mgmt_grp, true) == true
  }
}

// Assign policy definitions
// only if variable deploy_custom_policies is set to true
resource "azurerm_management_group_policy_assignment" "filebased" {
  for_each             = var.deploy_policies ? {
    for policy_name, policy_data in local.filebased_mgmt_grp_policies : policy_name => policy_data 
      if try(policy_data.assign_to_mgmt_grp, true) == true
  } : {}
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  policy_definition_id = azurerm_policy_definition.filebased[each.key].id
  management_group_id  = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
  parameters           = try(each.value.parameters, jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"]))
  depends_on           = [azurerm_policy_definition.filebased]
}

resource "azurerm_management_group_policy_assignment" "builtin" {
  for_each             = var.deploy_policies ? local.builtin_mgmt_grp_policies : {}
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  policy_definition_id = each.value.policy_definition_id
  parameters           = jsonencode(jsondecode(file("${path.module}/policies/${each.key}/${each.value.policy_filename}"))["properties"]["parameters"])
  management_group_id  = "/providers/Microsoft.Management/managementGroups/${split("/", each.key)[length(split("/", each.key)) - 2]}"
}
