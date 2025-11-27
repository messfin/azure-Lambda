# CI/CD Quick Start Guide

Get your CI/CD pipeline running in 5 minutes!

## 🚀 Quick Setup by Platform

### GitHub Actions (2 minutes)

1. **Add secrets:**
   ```
   Repository → Settings → Secrets → Actions
   Add: AWS_ACCESS_KEY_ID
   Add: AWS_SECRET_ACCESS_KEY
   ```

2. **Push code:**
   ```bash
   git add .github/workflows/lambda-tests.yml
   git commit -m "Add CI/CD pipeline"
   git push
   ```

3. **Done!** Check Actions tab for results.

---

### Azure DevOps (3 minutes)

1. **Create service connection:**
   ```
   Project Settings → Service connections → New
   Type: AWS
   Name: AWS Service Connection
   Add your AWS credentials
   ```

2. **Create pipeline:**
   ```
   Pipelines → New → Existing YAML
   Path: azure-pipelines-lambda.yml
   Run pipeline
   ```

3. **Done!** Check Pipelines tab for results.

---

### GitLab CI/CD (2 minutes)

1. **Add variables:**
   ```
   Settings → CI/CD → Variables
   Add: AWS_ACCESS_KEY_ID (masked)
   Add: AWS_SECRET_ACCESS_KEY (masked, protected)
   Add: AWS_DEFAULT_REGION = us-east-1
   ```

2. **Push code:**
   ```bash
   git add .gitlab-ci.yml
   git commit -m "Add CI/CD pipeline"
   git push
   ```

3. **Done!** Check CI/CD → Pipelines for results.

---

## 🧪 Test the Pipeline Locally

Before pushing, test locally:

**Linux/Mac:**
```bash
chmod +x ci-run-tests.sh
./ci-run-tests.sh
```

**Windows:**
```powershell
.\ci-run-tests.ps1
```

---

## ✅ Verification Checklist

- [ ] AWS credentials configured
- [ ] Lambda function deployed (`serverless deploy`)
- [ ] Test runner script works locally
- [ ] Pipeline file committed to repository
- [ ] Secrets/variables added to CI/CD platform
- [ ] Pipeline triggered and running

---

## 🐛 Common Issues

**"AWS credentials not found"**
→ Add secrets/variables to your CI/CD platform

**"Lambda function not found"**
→ Run `serverless deploy` first

**"Tests failing"**
→ Check CloudWatch logs for Lambda errors

---

## 📚 Next Steps

- Read [CI-CD-SETUP.md](./CI-CD-SETUP.md) for detailed configuration
- Read [HOW-TO-RUN-TESTS.md](./HOW-TO-RUN-TESTS.md) for local testing
- Customize test files in pipeline configuration

