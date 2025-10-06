
resource "local_file" "variable_output" {

  for_each = var.generate_env_files ? { for item in local.template_items : "${item.envname}-${item.file}" => item } : {}

  content  = templatefile("${path.module}/templates/${each.value.file}", { items = each.value.items })
  filename = "${path.module}/${var.output_path}/terraform/${each.value.envname}-${var.stage_name}-${trimsuffix(each.value.file, ".tpl")}"

}
