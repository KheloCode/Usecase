provider "aws" {
  region = "us-east-1"
}

# S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket = "my-static-site-bucket-12345"

  website {
    index_document = "index.html"
  }

  acl = "public-read"
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = "*",
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.website.arn}/*"
    }]
  })
}

# S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "artifact" {
  bucket = "my-pipeline-artifacts-bucket-12345"
}

# CodeCommit repository
resource "aws_codecommit_repository" "repo" {
  repository_name = "static-site-repo"
  description     = "Repo for static site"
}

# CodeBuild project
resource "aws_codebuild_project" "project" {
  name         = "static-site-build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type     = "CODECOMMIT"
    location = aws_codecommit_repository.repo.clone_url_http
    buildspec = "buildspec.yml"
  }
}

# CodePipeline
resource "aws_codepipeline" "pipeline" {
  name     = "static-site-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifact.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = aws_codecommit_repository.repo.name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.project.name
      }
    }
  }
}
