#!/usr/bin/env python3
"""
Lambda Function Packager
Creates deployment packages for all Lambda functions
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

# Configuration
BASE_DIR = Path(__file__).parent.parent
LAMBDA_DIR = BASE_DIR / "src" / "lambda-functions"
BUILD_DIR = BASE_DIR / "build"

FUNCTIONS = [
    "scan-processor",
    "vulnerability-aggregator",
    "policy-enforcer",
    "slack-notifier"
]

def create_zip(source_dir, output_file):
    """Create a ZIP file from a directory"""
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, source_dir)
                zipf.write(file_path, arcname)
    
def package_function(func_name):
    """Package a single Lambda function"""
    print(f"\n📦 Packaging: {func_name}")
    
    func_dir = LAMBDA_DIR / func_name
    package_dir = BUILD_DIR / func_name
    zip_file = BUILD_DIR / f"{func_name}.zip"
    
    # Clean previous build
    if package_dir.exists():
        shutil.rmtree(package_dir)
    if zip_file.exists():
        zip_file.unlink()
    
    # Create package directory
    package_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy handler
    handler_src = func_dir / "handler.py"
    handler_dst = package_dir / "handler.py"
    
    if not handler_src.exists():
        print(f"  ❌ Error: handler.py not found in {func_dir}")
        return False
    
    shutil.copy2(handler_src, handler_dst)
    print(f"  ✓ Copied handler.py")
    
    # Copy requirements if needed (boto3 is provided by Lambda)
    req_file = func_dir / "requirements.txt"
    if req_file.exists():
        content = req_file.read_text()
        if content.strip() and not content.strip().startswith('#'):
            print(f"  ℹ️  Note: boto3/botocore provided by Lambda runtime")
    
    # Create ZIP
    create_zip(package_dir, zip_file)
    
    # Get size
    size_mb = zip_file.stat().st_size / (1024 * 1024)
    print(f"  ✓ Created: {func_name}.zip ({size_mb:.2f} MB)")
    
    # Clean up temp directory
    shutil.rmtree(package_dir)
    
    return True

def main():
    """Main function"""
    print("=" * 60)
    print("Lambda Function Deployment Packager")
    print("=" * 60)
    
    # Create build directory
    BUILD_DIR.mkdir(exist_ok=True)
    
    success_count = 0
    
    for func in FUNCTIONS:
        if package_function(func):
            success_count += 1
    
    print("\n" + "=" * 60)
    print(f"✅ Packaging Complete: {success_count}/{len(FUNCTIONS)} functions")
    print("=" * 60)
    print(f"\nDeployment packages created in: {BUILD_DIR}/")
    print("\nTo update Lambda functions, run:")
    print("  terraform apply")
    print("\nOr use AWS CLI:")
    for func in FUNCTIONS:
        print(f"  aws lambda update-function-code \\")
        print(f"    --function-name container-scanning-{func}-dev \\")
        print(f"    --zip-file fileb://build/{func}.zip\n")

if __name__ == "__main__":
    main()
