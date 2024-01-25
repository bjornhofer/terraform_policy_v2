// Build folder structure for initiatives
locals {
  folderstructure_initiatives = [for folder in fileset(path.module, "**") : folder
  if(length(regexall("(\\.json)", folder)) > 0) && split("/", folder)[0] == "initiatives"]
  folders_initiatives = distinct(flatten([for folder in local.folderstructure_initiatives : join("/", slice(split("/", folder), 0, length(split("/", folder)) - 1))]))
}

locals {
  // Management Group Settings - initiatives
  management_group_initiative_file_name = "initiatives.json"
  mgmt_grp_layer0_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 1] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  mgmt_grp_layer1_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 2] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  mgmt_grp_layer2_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 3] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  mgmt_grp_layer3_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 4] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  mgmt_grp_layer4_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 5] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  mgmt_grp_layer5_initiatives           = { for folder in [for layers in local.folders_initiatives : layers if length(split("/", layers)) == 6] : folder => try(jsondecode(file("${path.module}/${folder}/${local.management_group_initiative_file_name}")), {}) }
  // Test to iterate only over the first two layers
  unfiltered_mgmt_grp_initiatives = merge(local.mgmt_grp_layer0_initiatives, local.mgmt_grp_layer1_initiatives, local.mgmt_grp_layer2_initiatives, local.mgmt_grp_layer3_initiatives, local.mgmt_grp_layer4_initiatives, local.mgmt_grp_layer5_initiatives)

  // Filter the initiatives (remove empty entries in map)
  // File based initiative definition
  filebased_mgmt_grp_initiatives_temp = {
    for mgmt_grp, initiativedata in local.unfiltered_mgmt_grp_initiatives : mgmt_grp => {
      for initiative_name, initiative_information in initiativedata :
      initiative_name => initiative_information
      if try(initiative_information.project_name, false) == false &&
    try(initiative_information.initiative_definition_id, false) == false }
  if length(initiativedata) > 0 }

  // existing initiative definition
  existing_mgmt_grp_initiatives_temp = {
    for mgmt_grp, initiativedata in local.unfiltered_mgmt_grp_initiatives : mgmt_grp => {
      for initiative_name, initiative_information in initiativedata :
      initiative_name => initiative_information
      if try(initiative_information.project_name, false) == false &&
    try(initiative_information.initiative_definition_id, false) != false }
  if length(initiativedata) > 0 }


  // Build final initiative map
  // File based initiative definition

  filebased_mgmt_grp_initiatives = merge([
    for mgmt_grp, initiativedata in local.filebased_mgmt_grp_initiatives_temp :
    { for initiative_information in initiativedata :
      "${mgmt_grp}/${initiative_information.initiative_filename}" => merge(initiative_information, { management_group_id = trimprefix(mgmt_grp, "initiatives/") }, { policy_type = try(initiative_information.policy_type, "Custom") })
      if length(initiativedata) > 0
    }
  ]...)

  // existing initiative definition
  existing_mgmt_grp_initiatives = merge([
    for mgmt_grp, initiativedata in local.existing_mgmt_grp_initiatives_temp :
    { for initiative_information in initiativedata :
      "${mgmt_grp}/${try(initiative_information.initiative_filename, initiative_information.initiative_name, initiative_information.assignment_name)}" => merge(initiative_information, { management_group_id = trimprefix(mgmt_grp, "initiatives/") }, { policy_type = try(initiative_information.policy_type, "Custom") })
      if length(initiativedata) > 0
    }
  ]...)

}

// DEBUG section
output "filebased_mgmt_grp_initiatives" {
  value = local.verbose ? local.filebased_mgmt_grp_initiatives : null
}

output "existing_mgmt_grp_initiatives" {
  value = local.verbose ? local.existing_mgmt_grp_initiatives : null
}

output "filebased_management_group_data_initiatives" {
  value = local.verbose ? [for filename, initiativedata in local.filebased_mgmt_grp_initiatives : split("/", initiativedata.management_group_id)[length(split("/", initiativedata.management_group_id)) - 1]] : null
}

output "existing_management_group_data_initiatives" {
  value = local.verbose ? [for filename, initiativedata in local.existing_mgmt_grp_initiatives : split("/", initiativedata.management_group_id)[length(split("/", initiativedata.management_group_id)) - 1]] : null
}

// Gather data from manamgement groups to be able to define/assign initiatives
// split is needed due to inability of module to handle full path of manamgement group id
data "azurerm_management_group" "filebased_mangement_group_initiatives" {
  for_each = local.filebased_mgmt_grp_initiatives
  name     = split("/", each.value.management_group_id)[length(split("/", each.value.management_group_id)) - 1]
}

data "azurerm_management_group" "existing_mangement_group_initiatives" {
  for_each = local.existing_mgmt_grp_initiatives
  name     = split("/", each.value.management_group_id)[length(split("/", each.value.management_group_id)) - 1]
}

// Deploy initiative defintions
// initiatives with initiative_rule defined
resource "azurerm_policy_set_definition" "filebased" {
  for_each            = local.filebased_mgmt_grp_initiatives
  name                = try(each.value.definition_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name        = try(each.value.definition_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"])
  description         = try(each.value.definition_description, jsondecode(file("${path.module}/${each.key}"))["properties"]["description"])
  policy_type         = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["initiativeType"], "Custom")
  parameters          = jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"])
  management_group_id = data.azurerm_management_group.filebased_mangement_group_initiatives[each.key].id
  dynamic "policy_definition_reference" {
    for_each = try(jsondecode(file("${path.module}/${each.key}"))["properties"]["policyDefinitions"], {})
    content {
      policy_definition_id = policy_definition_reference.value.policyDefinitionId
      parameter_values     = jsonencode(policy_definition_reference.value.parameters)
    }
  }
}

// Assign initiative definitions
resource "azurerm_management_group_policy_assignment" "inititave_filebased" {
  for_each = {
    for initiative_name, initiative_data in local.filebased_mgmt_grp_initiatives : initiative_name => initiative_data
    if try(initiative_data.assign_to_mgmt_grp, true) == true
  }
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name         = try(each.value.assignment_display_name, each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  policy_definition_id = azurerm_policy_set_definition.filebased[each.key].id
  management_group_id  = data.azurerm_management_group.filebased_mangement_group_initiatives[each.key].id
  parameters           = try(jsonencode(each.value.parameters), jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"]))
  enforce              = try(each.value.enforce, true)
  depends_on           = [azurerm_policy_set_definition.filebased]
}

resource "azurerm_management_group_policy_assignment" "initiative_existing" {
  for_each             = local.existing_mgmt_grp_initiatives
  name                 = try(each.value.assignment_name, jsondecode(file("${path.module}/${each.key}"))["name"])
  display_name         = try(each.value.assignment_display_name, jsondecode(file("${path.module}/${each.key}"))["properties"]["displayName"], jsondecode(file("${path.module}/${each.key}"))["name"], each.value.assignment_name)
  policy_definition_id = each.value.initiative_definition_id
  parameters           = try(jsonencode(each.value.parameters), jsonencode(jsondecode(file("${path.module}/${each.key}"))["properties"]["parameters"]))
  enforce              = try(each.value.enforce, true)
  management_group_id  = data.azurerm_management_group.existing_mangement_group_initiatives[each.key].id
}
