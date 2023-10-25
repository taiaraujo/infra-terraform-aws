provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "ddb_table" {
  name = var.table_name
  hash_key = "id"
  billing_mode = "PROVISIONED"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "write_role" {
  name = "lambda_write_role"
  assume_role_policy = file("./roles/assume_write_role_policy.json")
}

resource "aws_iam_role_policy" "write_policy" {
 name = "lambda_write_policy"
 role = aws_iam_role.write_role.id
 policy = file("./roles/write_policy.json") 
}

resource "aws_iam_role" "read_role" {
  name = "lambda_read_role"
  assume_role_policy = file("./roles/assume_read_role_policy.json")
}

resource "aws_iam_role_policy" "read_policy" {
 name = "lambda_read_policy"
 role = aws_iam_role.read_role.id
 policy = file("./roles/read_policy.json") 
}

resource "aws_lambda_function" "register_client" {
  function_name = "register_client"
  s3_bucket = "terraform_bucket"
  s3_key = "lambdaRegisterClient.zip"
  role = aws_iam_role.write_role.arn
  handler = "lambdaRegisterClient.handler"
  runtime = "nodejs14.x"
}

resource "aws_lambda_function" "find_client" {
  function_name = "find_client"
  s3_bucket = "terraform_bucket"
  s3_key = "lambdaFindClient.zip"
  role = aws_iam_role.read_role.arn
  handler = "lambdaFindClient.handler"
  runtime = "nodejs14.x"
}

resource "aws_api_gateway_rest_api" "lambda_api" {
  name = "terraformAPI"
}

resource "aws_api_gateway_resource" "write_resource" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part = "insert"
}

resource "aws_api_gateway_method" "write_method" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.write_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "read_resource" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part = "get"
}

resource "aws_api_gateway_method" "read_method" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.write_resource.id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "write_internal" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.write_resource.id
  http_method = aws_api_gateway_method.write_method.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.register_client.invoke_arn
}

resource "aws_api_gateway_integration" "read_internal" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_resource.write_resource.id
  http_method = aws_api_gateway_method.write_method.http_method

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.find_client.invoke_arn
}

resource "aws_api_gateway_deployment" "deploy_api" {
  depends_on = [aws_api_gateway_integration.write_internal, aws_api_gateway_integration.read_internal]
  rest_api_id = aws_api_gateway_rest_api.lambda_api.parent_id
  stage_name = "dev"
}

resource "aws_lambda_permission" "write_permission" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register_client.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/dev/POST/get"
}

resource "aws_lambda_permission" "read_permission" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.find_client.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/dev/POST/get"
}

output "base_url" {
  value = aws_api_gateway_deployment.deploy_api.invoke_url 
}
