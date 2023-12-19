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

  // existing policy definition
  existing_mgmt_grp_policies_temp = {
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
      "${mgmt_grp}/${policy_information.policy_filename}" => merge(policy_information, { management_group_id = trimprefix(mgmt_grp, "policies/") })
    } if length(policydata) > 0
  ]...)

  // existing policy definition
  existing_mgmt_grp_policies = merge([
    for mgmt_grp, policydata in local.existing_mgmt_grp_policies_temp :
    { for policy_information in policydata :
      "${mgmt_grp}/${try(policy_information.policy_filename, policy_information.policy_name, policy_information.assignment_name)}" => merge(policy_information, { management_group_id = trimprefix(mgmt_grp, "policies/") })
    } if length(policydata) > 0
  ]...)
}

// DEBUG section
output "filebased_mgmt_grp_policies" {
  value = local.verbose ? local.filebased_mgmt_grp_policies : null
}
output "existing_mgmt_grp_policies" {
  value = local.verbose ? local.existing_mgmt_grp_policies : null
}

output "filebased_management_group_data" {
  value = local.verbose ? [for filename, policydata in local.filebased_mgmt_grp_policies : split("/", policydata.management_group_id)[length(split("/", policydata.management_group_id)) - 1]] : null
}

output "existing_management_group_data" {
  value = local.verbose ? [for filename, policydata in local.existing_mgmt_grp_policies : split("/", policydata.management_group_id)[length(split("/", policydata.management_group_id)) - 1]] : null
}

// Gather data from manamgement groups to be able to define/assign policies
// split is needed due to inability of module to handle full path of manamgement group id
data "azurerm_management_group" "filebased_mangement_group" {
  for_each = local.filebased_mgmt_grp_policies
  name     = split("/", each.value.management_group_id)[length(split("/", each.value.management_group_id)) - 1]
}

data "azurerm_management_group" "existing_mangement_group" {
  for_each = local.existing_mgmt_grp_policies
  name     = split("/", each.value.management_group_id)[length(split("/", each.value.management_group_id)) - 1]
}

// Deploy policiy defintions
// Policies with policy_rule defined
resource "azurerm_policy_definition" "filebased" {
  for_each = {
    for policy_name, policy_data in local.filebased_mgmt_grp_policies : policy_name => policy_data
    if try(jsondecode(file("${path.module}/${policy_name}"))["properties"]["policyRule"], false) != false
  }
  name         = try(each.value.definition_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name = try(each.value.definition_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"])
  description  = try(each.value.definition_description, jsondecode(file("${path.module}/${each.key}"))["properties"]["description"])
  policy_type  = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["policyType"], "Custom")
  mode         = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["mode"], "All")
  parameters          = jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"])
  policy_rule         = jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["policyRule"])
  management_group_id = data.azurerm_management_group.filebased_mangement_group[each.key].id
}


// Policies without policy_rule defined
resource "azurerm_policy_definition" "filebased_empty_policy_rule" {
  for_each = {
    for policy_name, policy_data in local.filebased_mgmt_grp_policies : policy_name => policy_data
    if try(jsondecode(file("${path.module}/${policy_name}"))["properties"]["policyRule"], false) == false
  }
  name                = try(each.value.definition_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name        = try(each.value.definition_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"])
  description         = try(each.value.definition_description, jsondecode(file("${path.module}/${each.key}"))["properties"]["description"])
  policy_type         = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["policyType"], "Custom")
  mode                = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["mode"], "All")
  parameters          = jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"])
  management_group_id = data.azurerm_management_group.filebased_mangement_group[each.key].id
}

// Assign policy definitions
resource "azurerm_management_group_policy_assignment" "filebased" {
  for_each = {
    for policy_name, policy_data in local.filebased_mgmt_grp_policies : policy_name => policy_data
    if try(policy_data.assign_to_mgmt_grp, true) == true
  }
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name         = try(each.value.assignment_display_name, each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  policy_definition_id = merge(azurerm_policy_definition.filebased, azurerm_policy_definition.filebased_empty_policy_rule)[each.key].id
  management_group_id  = data.azurerm_management_group.filebased_mangement_group[each.key].id
  parameters           = try(jsonencode(each.value.parameters), jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"]))
  enforce              = try(each.value.enforce, true)
  depends_on           = [azurerm_policy_definition.filebased]
}

resource "azurerm_management_group_policy_assignment" "existing" {
  for_each             = local.existing_mgmt_grp_policies
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name         = try(each.value.assignment_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"], jsondecode(file("${path.module}/${each.key}"))["name"], each.value.assignment_name)
  policy_definition_id = each.value.policy_definition_id
  parameters           = try(jsonencode(each.value.parameters), jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"]))
  enforce              = try(each.value.enforce, true)
  management_group_id  = data.azurerm_management_group.existing_mangement_group[each.key].id
}
