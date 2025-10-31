"""
Sample Vulnerable Web Application
For testing container security scanning
"""

from flask import Flask, request, render_template_string
import requests

app = Flask(__name__)

@app.route('/')
def home():
    return '''
    <h1>Vulnerable Test Application</h1>
    <p>This application intentionally contains vulnerabilities for testing:</p>
    <ul>
        <li>Old Python base image</li>
        <li>Outdated dependencies with known CVEs</li>
        <li>Insecure code patterns</li>
    </ul>
    <p><a href="/fetch?url=http://example.com">Test SSRF</a></p>
    <p><a href="/render?template=Hello">Test Template Injection</a></p>
    '''

@app.route('/fetch')
def fetch_url():
    # SSRF vulnerability - accepts any URL
    url = request.args.get('url', 'http://example.com')
    try:
        response = requests.get(url)
        return f"<pre>{response.text}</pre>"
    except Exception as e:
        return f"Error: {str(e)}"

@app.route('/render')
def render_template():
    # Template injection vulnerability
    template = request.args.get('template', 'Hello')
    return render_template_string(template)

@app.route('/health')
def health():
    return {'status': 'healthy', 'version': '1.0.0'}

if __name__ == '__main__':
    # Insecure: debug mode in production
    app.run(host='0.0.0.0', port=5000, debug=True)
