
# add oidc provider to the new account for github actions
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  provider        = aws.assumed
}

/*
aws sts assume-role assume-role --role-arn arn:aws:iam::358258037662:role/iac --role-session-name assume-role
*/
