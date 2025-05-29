# Licentra

> A modern license key management system built with Ruby Sinatra and PostgreSQL

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-3.0+-red.svg)](https://ruby-lang.org)
[![PostgreSQL](https://img.shields.io/badge/postgresql-15+-blue.svg)](https://postgresql.org)

## 🚀 Features

- **License Management**: Create, assign, and track software licenses
- **User & Role Management**: Granular access control and permissions
- **Automated Monitoring**: Real-time license validation and notifications
- **Web Dashboard**: Intuitive admin interface with Bootstrap UI
- **Microservices Architecture**: Scalable Docker-based deployment
- **SMTP Integration**: Configurable mail server support
- **Security First**: SQL injection protection via ORM
- **Production Ready**: Reverse proxy with SSL/TLS support

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)


## ⚡ Quick Start

**Development Environment** - Includes mock data for testing

**Clone the repository**
```
git clone https://github.com/Project-FleX-PFX/Licentra.git
cd Licentra
```
**Copy environment configuration and set up as needed**
```
cp ._env .env
```
**Start all services**
```
docker compose up --build
```
**Access the application**
```
open http://localhost:4567
```
### 🔑 Default Test Credentials

For development and testing purposes, use these pre-configured credentials:

- **Username**: `user@company.local`
- **Password**: `secureAdminPass123!`

> ⚠️ **Note**: This is a development environment with mock data. Never use these credentials in production!

### 🎯 What's Included

- **Mock License Data**: Pre-populated licenses for testing
- **Sample Users**: Test accounts with different permission levels
- **Development Database**: PostgreSQL with seed data
- **Hot Reload Frontend**: Changes reflect immediately during development

**Ready in 3 minutes!** 🚀

---

*For production deployment, see the [Deployment](#deployment) section.*

## 📦 Prerequisites

Licentra runs entirely in Docker containers, making it platform-independent with minimal requirements.

### Required Software

- **Docker** >= 20.10
- **Docker Compose** >= 2.0

> 💡 **That's it!** No local Ruby, PostgreSQL, or other dependencies needed - everything runs in containers.

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 2 GB | 4 GB+ |
| **CPU** | 2 cores | 4 cores+ |
| **Storage** | 5 GB free | 10 GB+ free |
| **OS** | Any Docker-supported OS | Linux/macOS/Windows |

### Network Requirements

The following ports must be available on your development machine:

- **Port 4567**: Backend API and web interface
- **Port 6543**: PostgreSQL database

> ⚠️ **Important**: If these ports are occupied, Docker Compose will fail to start. Check with:
> ```
> # Check if ports are free
> netstat -an | grep :4567
> netstat -an | grep :6543
> ```

### Platform Support

✅ **Linux** (Ubuntu, CentOS, Debian, etc.)  
✅ **macOS** (Intel & Apple Silicon)  
✅ **Windows** (with WSL2 recommended)  
✅ **Cloud platforms** (AWS, GCP, Azure)

---

*Next: [Installation](#installation) for step-by-step setup instructions.*

## 🛠 Installation

### Development Environment

**Clone the repository**

```
git clone https://github.com/Project-FleX-PFX/Licentra.git
cd Licentra
```
**Copy environment configuration and set up as needed**
```
cp ._env .env
```
**Start all services**
```
docker compose up --build
```

### Docker Installation Example (WSL2 on Windows)

If you need to install Docker on Windows using WSL2 (recommended for corporate environments):

**1. Install WSL2 with Ubuntu**
```
wsl --install
wsl --list --online
wsl --install -d Ubuntu-24.04
```
**2. Update system packages**
```
sudo apt update && sudo apt upgrade -y
```

**3. Install dependencies**

```
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
```

**4. Add Docker GPG key**

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

**5. Setup Docker repository**

```
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

**6. Update package lists**

```
sudo apt update
```

**7. Install Docker**

```
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**8. Add user to docker group (optional)**

```
sudo usermod -aG docker $USER
```

**9. Restart WSL session**

```
exit

wsl --shutdown
wsl -d Ubuntu-24.04
```

> 💡 **Note**: This avoids Docker Desktop licensing issues in corporate environments.

### Verification

**Test Docker installation**

```
docker --version
docker compose version
```

**Test Licentra setup**

In your licentra directory:

```
docker compose up --build
```


**Access the application**
- Open your browser and navigate to `http://localhost:4567`
- Use test credentials: `user@company.local` / `secureAdminPass123!`

---

*Next: [Configuration](#configuration) for environment customization.*

## ⚙️ Configuration

Licentra uses environment variables for all configuration, making it easy to deploy across different environments without code changes.

### Environment Variables

All configuration is managed through the `.env` file. Copy the template and customize for your environment:

```
cp ._env .env
```


#### Required Variables

| Variable | Description | Example | Notes |
|----------|-------------|---------|-------|
| `POSTGRES_USER` | Database username | `licentra_user` | Choose a secure username |
| `POSTGRES_PASSWORD` | Database password | `MySecure_Pass123!` | Use a strong password |
| `POSTGRES_DB` | Database name | `licentra_production` | Environment-specific naming |
| `SESSION_SECRET` | Session encryption key | `a1b2c3d4e5f6...` | **32-byte hex string** |
| `ENCRYPTION_KEY` | Data encryption key | `f6e5d4c3b2a1...` | **32-byte hex string** |
| `APP_BASE_URL` | Application URL | `https://licenses.company.com` | Production URL |

> ⚠️ **Security**: Generate secure 32-byte hex keys using: `openssl rand -hex 32`

#### Example .env File

```
# Database Configuration
POSTGRES_USER="licentra_admin"
POSTGRES_PASSWORD="SuperSecure_DB_Pass_2024!"
POSTGRES_DB="licentra_production"

# Application Security
SESSION_SECRET="a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
ENCRYPTION_KEY="fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"

# Production Settings
APP_BASE_URL="https://licenses.yourcompany.com"
```

### Docker Compose Profiles

Licentra supports different deployment scenarios through Docker Compose profiles:

#### Development (Default)

```
docker compose up --build
```
- **Includes**: Database, Backend, Frontend
- **Ports exposed**: 4567 (app), 6543 (database)
- **Use case**: Local development and testing
- **Files used**: `docker-compose.yml` + `docker-compose.override.yml`

#### #### Production Testing (Internal Networks Only)
```
docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.override.yml up -d --build
```
- **Includes**: Database, Backend, Frontend
- **Ports exposed**: 4567 (app), 6543 (database)
- **Use case**: Internal testing, staging environments
- **⚠️ Warning**: Only use on secured internal networks

#### Production with Reverse Proxy
```
docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile proxy up -d --build
```
- **Includes**: Database, Backend, Frontend, Nginx Proxy Manager
- **Ports exposed**: 80 (HTTP), 443 (HTTPS), 81 (Proxy Admin)
- **Use case**: Production deployment with SSL/TLS
- **Security**: Database not directly accessible

> 🚨 **Critical Security Warning**:
>
> **NEVER** use `docker-compose.override.yml` in production environments accessible from external networks!
>
> **Recommended deployment patterns:**
> ```
> # ✅ SECURE - Production with reverse proxy (RECOMMENDED)
> docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile proxy up -d
> 
> # ⚠️ CAUTION - Only for secured internal networks
> docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.override.yml up -d
> 
> # ❌ NEVER - Exposes database to external networks
> docker compose up -d
> ```

### File Structure

```
Licentra/
├── ._env # Environment template
├── .env # Your configuration (create this)
├── docker-compose.yml # Base services
├── docker-compose.prod.yml # Production overrides
├── docker-compose.override.yml # Development port exposure
├── npm-data/ # Nginx Proxy Manager data
└── npm-letsencrypt/ # SSL certificates
```


> 💡 **Note**: `docker-compose.override.yml` is automatically loaded by Docker Compose when no `-f` flags are specified.

### Profile Usage

The `proxy` profile controls the Nginx Proxy Manager service:

```
nginx-proxy-manager:
image: jc21/nginx-proxy-manager:latest
profiles: ["proxy"] # Only starts when --profile proxy is used
```

### Environment-Specific Configurations


#### Development
- **Database**: Accessible on `localhost:6543`
- **Backend**: API on `localhost:4567`
- **Frontend**: Hot reload enabled
- **Data**: Mock data included
- **Security**: Relaxed for development ease

#### Production
- **Database**: Internal network only, no external access
- **Backend**: Behind reverse proxy
- **Frontend**: Served through Nginx
- **SSL/TLS**: Automatic certificate management
- **Security**: Hardened configuration

### Security Best Practices

1. **Never commit `.env` files** - Use `._env` as template only
2. **Generate unique secrets** - Use `openssl rand -hex 32` for keys
3. **Use strong passwords** - Database passwords should be complex
4. **Restrict network access** - Use profiles to control service exposure
5. **Regular key rotation** - Change secrets periodically
6. **Explicit File Usage**: Always specify `-f` flags in production scripts

### Troubleshooting Configuration

**Check merged configuration:**

```
docker compose config
```

**Verify environment variables:**

```
docker compose config --services
docker compose config --volumes
```

**Check service status:**
```
docker compose ps
docker compose logs [backend] | grep -i database
```

**Test configuration without starting:**

```
docker compose -f docker-compose.yml -f docker-compose.prod.yml config
```

---
*Next: [Deployment](#deployment) for production deployment strategies.*

## 🚀 Deployment

This section covers production deployment with security best practices, firewall configuration, and advanced security options.

### Production Deployment

#### 1. Basic Production Setup

**Deploy with reverse proxy (recommended):**

```
docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile proxy up -d --build
```

**Verify deployment**

```
docker compose ps
docker compose logs nginx-proxy-manager
```


#### 2. Nginx Proxy Manager Configuration

After deployment, configure your reverse proxy:

**Access the admin interface:**
- URL: `http://your-server-ip:81`
- Default credentials: `admin@example.com` / `changeme`
- **⚠️ Change these immediately after first login!**

**Basic proxy host setup:**
1. Navigate to **Proxy Hosts** → **Add Proxy Host**
2. Configure your domain:
    - **Domain Names**: `licenses.yourcompany.com`
    - **Scheme**: `http`
    - **Forward Hostname/IP**: `backend`
    - **Forward Port**: `4567`
3. **SSL Tab**: Request new SSL certificate with Let's Encrypt
4. **Advanced Tab**: Add security headers if needed

### Firewall Configuration (Example, beware of SSH f.e.)

#### UFW (Ubuntu/Debian)

**Enable firewall with secure rules:**

**Reset firewall rules**
```
sudo ufw --force reset
```
**Default policies**
```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```
**Allow SSH (adjust port if needed)**
```
sudo ufw allow 22/tcp
```
**Allow HTTP/HTTPS for public access**
```
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```
**Allow admin interface ONLY for specific IPs**
```
sudo ufw allow from 192.168.1.0/24 to any port 81
sudo ufw allow from 10.0.0.0/8 to any port 81
# Add your admin IP ranges here
```
**Enable firewall**
```
sudo ufw enable
```
**Verify rules**
```
sudo ufw status numbered
```

#### iptables (Alternative)

**Flush existing rules**
```
iptables -F
```
**Default policies**
```
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```
**Allow loopback**
```
iptables -A INPUT -i lo -j ACCEPT
```
**Allow established connections**
```
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```
**Allow SSH**
```
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```
**Allow HTTP/HTTPS**
```
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```
**Allow admin interface for specific networks only**
```
iptables -A INPUT -p tcp --dport 81 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 81 -s 10.0.0.0/8 -j ACCEPT
# Add your admin IP ranges here
```
**Save rules (Ubuntu/Debian)**
```
iptables-save > /etc/iptables/rules.v4
```


### Advanced Security Options

#### Option 1: CrowdSec Integration

CrowdSec provides real-time threat detection and automatic IP blocking:

**Install CrowdSec on host:**

```
curl -s https://install.crowdsec.net | sudo bash
sudo systemctl enable crowdsec
sudo systemctl start crowdsec
```

**Configure Nginx log monitoring:**

```
# Install Nginx collection
sudo cscli collections install crowdsecurity/nginx

# Configure log paths (adjust to your npm-data location)
sudo nano /etc/crowdsec/acquis.yaml
```

Add to acquis.yaml:

```
filenames:
  - /path/to/npm-data/logs/*.log
labels:
  - type: nginx
```

**Install bouncer for automatic blocking:**

```
sudo cscli bouncers add nginx-bouncer
```

**Configure the bouncer with your Nginx Proxy Manager**


#### Option 2: Cloudflare Zero Trust

For maximum security, use Cloudflare Tunnels to eliminate exposed ports entirely[4]:

**Benefits:**
- No open ports on your server
- DDoS protection by Cloudflare
- Geographic access restrictions
- Advanced authentication options

**Setup process:**
1. Create Cloudflare account and add your domain
2. Install cloudflared on your server
3. Create tunnel: `cloudflared tunnel create licentra`
4. Configure tunnel to point to `http://localhost:4567`
5. Update firewall to block ports 80/443 (tunnel handles everything)


### Security Checklist

#### Essential Security Measures

- [ ] **Firewall configured** - Only ports 80, 443, and restricted 81 open
- [ ] **Admin access restricted** - Port 81 limited to specific IP ranges
- [ ] **Strong passwords** - Changed default NPM credentials
- [ ] **SSL certificates** - Let's Encrypt configured for all domains
- [ ] **Environment variables** - Secure secrets in `.env` file
- [ ] **Database access** - No direct external database access
- [ ] **Regular updates** - Keep Docker images updated

#### Advanced Security Measures

- [ ] **CrowdSec deployed** - Real-time threat detection active
- [ ] **Cloudflare integration** - Zero Trust architecture implemented
- [ ] **Access logs monitored** - Log analysis and alerting configured
- [ ] **Backup strategy** - Regular backups of configuration and data
- [ ] **Intrusion detection** - Additional monitoring tools deployed

### Monitoring and Maintenance

#### Health Checks

**Check service status:**

```
docker compose ps
```

**Monitor logs:**

```
# Application logs
docker compose logs -f backend

# Proxy logs
docker compose logs -f nginx-proxy-manager

# System logs
sudo journalctl -u docker -f
```


#### Regular Maintenance

**Update containers:**
```
git pull
docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile proxy up -d --build
```

**Backup configuration:**

```
# Backup NPM data
tar -czf npm-backup-$(date +%Y%m%d).tar.gz npm-data/ npm-letsencrypt/

# Backup application data
docker compose exec db pg_dump -U $POSTGRES_USER $POSTGRES_DB > backup-$(date +%Y%m%d).sql
```


### Troubleshooting Deployment

#### Common Issues

**Port conflicts:**

```
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
sudo netstat -tlnp | grep :81
```

**SSL certificate issues:**

```
docker compose logs nginx-proxy-manager | grep -i ssl
```

**Database connection issues:**

```
docker compose exec backend ruby -e "require 'sequel'; puts Sequel.connect(ENV['DATABASE_URL']).test_connection"
```


#### Performance Optimization

**For high-traffic deployments:**

```
services:
  nginx-proxy-manager:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
  backend:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

```


---

*Next: [API Documentation](#api-documentation) for integration details.*

## 📚 API Documentation

Licentra is primarily a web-based license management system with **no external REST API**. All functionality is accessed through the web interface.

### SMTP Configuration

Licentra uses SMTP for **password reset functionality only**. SMTP settings are configured through the **admin web interface** - no manual file editing required!

#### Admin Interface SMTP Setup

**Access SMTP settings:**
1. Log in to Licentra admin panel
2. Navigate to **SMTP Settings**
3. Configure your email provide settings

**Required SMTP fields:**
- **Email Server Address**: Your provider's SMTP server (e.g., `smtp.gmail.com`)
- **Server Port**: Usually `587` (TLS) or `465` (SSL)
- **Security Type**: TLS/STARTTLS (recommended) or SSL
- **Email Address**: Your email account username
- **Password**: Your email account password (encrypted storage)

> 🔒 **Security**: All SMTP credentials are encrypted using your `ENCRYPTION_KEY` before database storage.

#### Common Provider Settings

| Provider | Server | Port | Security | Notes |
|----------|--------|------|----------|-------|
| **Gmail** | `smtp.gmail.com` | `587` | TLS | App password required |
| **Outlook/Hotmail** | `smtp-mail.outlook.com` | `587` | TLS | Modern auth recommended |
| **Office 365** | `smtp.office365.com` | `587` | TLS | SMTP AUTH must be enabled |
| **SendGrid** | `smtp.sendgrid.net` | `587` | TLS | API key as password |
| **Mailgun** | `smtp.mailgun.org` | `587` | TLS | Domain verification needed |

#### Testing SMTP Configuration

**Built-in test functionality:**
1. Save your SMTP settings in the admin interface
2. Use the **"Test Email Sending"** section
3. Enter a recipient email address
4. Click **"Send Test Email"**
5. Check if the test email arrives

> 💡 **Tip**: The admin interface provides user-friendly guidance for each setting - perfect for non-technical users!

### Web Interface Access

Licentra operates as a **web application** accessed through your browser:

- **Development**: `http://localhost:4567`
- **Production**: Your configured domain (e.g., `https://licenses.company.com`)

### Authentication

**Web-based login:**
- Access the login page through your browser
- Use credentials: `user@company.local` / `secureAdminPass123!` (development)
- Session-based authentication with secure cookies

### Available Functions

**Through the web interface:**
- **License Management**: Create, edit, delete, and assign licenses
- **User Management**: Manage user accounts and permissions
- **Dashboard**: Overview of license usage and statistics
- **Settings**: Configure SMTP, system settings, and preferences
- **Reports**: Generate license usage reports

### Integration Options

Since Licentra doesn't provide a REST API, integration options are limited to:

1. **Database Access**: Direct PostgreSQL database queries (advanced users only)
2. **Web Scraping**: Automated browser interactions (not recommended)
3. **Future Development**: REST API could be added if needed

> 💡 **Note**: If you need programmatic access to license data, consider requesting REST API development as a feature enhancement.

### Health Check

**Simple connectivity test:**

```
curl -I http://localhost:4567

Response:
HTTP/1.1 200 OK
```


### Security Features

- **Session Management**: Secure cookie-based sessions
- **Input Validation**: All user inputs escaped and validated
- **Encrypted Storage**: Sensitive data encrypted with `ENCRYPTION_KEY`
- **HTTPS Support**: SSL/TLS encryption via reverse proxy

### Troubleshooting Access

**Common issues:**

1. **Can't access web interface**:
    - Check if containers are running: `docker compose ps`
    - Verify port 4567 is accessible
    - Check firewall settings

2. **Login fails**:
    - Verify credentials (case-sensitive)
    - Check if database is connected
    - Review application logs: `docker compose logs backend`

3. **SMTP not working**:
    - Test SMTP settings in admin interface
    - Check provider-specific requirements
    - Verify firewall allows outbound SMTP connections

---

*Next: [Development](#development) for local development setup.*

## 💻 Development

Licentra's Docker-based architecture makes development setup incredibly simple. Most development tasks use the same commands as the Quick Start.

### Development Setup

**Clone and start (same as Quick Start):**
```

git clone https://github.com/Project-FleX-PFX/Licentra.git
cd Licentra
cp ._env .env
docker compose up --build

```

**Access the application:**
- **Frontend**: `http://localhost:4567`
- **Database**: `localhost:6543` (PostgreSQL)
- **Credentials**: `user@company.local` / `secureAdminPass123!`

### Project Structure

```
Licentra/
├── backend/                \# Ruby Sinatra backend
│   ├── config/             \# Configuration files
│   ├── dao/                \# Data Access Objects
│   ├── db/                 \# Database migrations \& seeds
│   │   └── migrations/     \# Database schema changes
│   ├── helpers/            \# Helpers for sinatra
│   ├── lib/                \# External libraries
│   ├── models/             \# Database Models
│   ├── routes/             \# Routes logic
│   ├── service/            \# Service clases for routes
│   ├── spec/               \# RSpec tests
│   └── Dockerfile
├── frontend/               \# Web interface
│   ├── views/              \# ERB templates
│   ├── public/             \# Static assets (CSS, JS, images)
├── docker-compose.yml      \# Development services
├── docker-compose.override.yml \# Port exposure for development
└── ._env                   \# Environment template

```

### Development Workflow

#### Making Changes

**Backend changes (Ruby/Sinatra):**
```
# Restart backend after code changes
docker compose restart backend

# Or rebuild if dependencies changed
docker compose up --build backend
```

**Frontend changes (ERB/CSS/JS):**
- Static files: Changes reflect immediately (hot reload)
- ERB templates: Restart backend to see changes

#### Database Operations

**Run migrations:**
```
docker compose exec backend bundle exec sequel -m db/migrations \$DATABASE_URL
```

**Access database directly:**
```
docker compose exec db psql -U \$POSTGRES_USER \$POSTGRES_DB
```

**Create new migration:**
```
docker compose exec backend bundle exec sequel -m db/migrations --create add_new_feature
```

#### Viewing Logs

**All services:**
```
docker compose logs -f
```

**Specific service:**
```
docker compose logs -f backend
docker compose logs -f db
```

### Testing

**Run all tests:**
```
docker compose exec backend bundle exec rspec
```

**Run specific test file:**
```
docker compose exec backend bundle exec rspec spec/models/license_spec.rb
```

**Run tests with coverage:**
```
docker compose exec backend bundle exec rspec --format documentation
```

### Common Development Tasks

#### Reset Development Environment

**Clean restart:**
```
docker compose down -v
docker compose up --build
```

**Reset database only:**
```
docker compose down db
docker volume rm licentra_postgres_data
docker compose up db
```

#### Debug Issues

**Check container status:**
```
docker compose ps
```

**Inspect container:**
```
docker compose exec backend bash
docker compose exec db bash
```

**Check environment variables:**
```
docker compose exec backend env | grep -E "(DATABASE|POSTGRES)"
```

### Development Tips

1. **Port Conflicts**: If ports 4567 or 6543 are in use, stop other services or change ports in `docker-compose.override.yml`

2. **Database Persistence**: Database data persists between restarts via Docker volumes

3. **File Permissions**: If you encounter permission issues, check Docker daemon configuration

4. **Performance**: On Windows/macOS, consider using Docker Desktop with WSL2 for better performance

5. **Hot Reload**: Frontend static files update immediately, but ERB templates require backend restart

### IDE Setup

**Recommended for Ruby development:**
- **VS Code** with Ruby extension
- **RubyMine** (JetBrains)
- **Vim/Neovim** with Ruby plugins

**Useful VS Code extensions:**
- Ruby
- Docker
- PostgreSQL
- ERB Helper/Rails

### Troubleshooting Development

**Container won't start:**
```
# Check logs for errors
docker compose logs backend

# Verify .env file exists and is configured
cat .env
```

**Database connection issues:**
```
# Test database connectivity
docker compose exec backend ruby -e "require 'sequel'; puts Sequel.connect(ENV['DATABASE_URL']).test_connection"
```

**Permission errors:**
```
# Fix file permissions (Linux/macOS)
sudo chown -R $USER:$USER .
```

---

*Next: [Testing](#testing) for comprehensive testing strategies.*

## 🧪 Testing

Licentra includes comprehensive backend testing with RSpec. Frontend testing is currently not implemented.

### Backend Testing

**Run all backend tests:**
```
docker compose run --rm backend bundle exec rspec
```

**Performance expectations:**
- **400+ test cases** covering core functionality
- **Runtime**: 2-3 minutes minimum
- **Coverage**: Models, controllers, business logic, and integrations

> ⏱️ **Note**: The test suite is comprehensive but takes time. Plan accordingly during development[^2][^4].

### Test Structure

**Backend test organization:**
```
backend/spec/
├── dao/              \# Data Access Objectes tests
├── routes/           \# Route and controller tests
```

### Running Specific Tests

**Single test file:**
```
docker compose run --rm backend bundle exec rspec spec/models/license_spec.rb
```

**Specific test pattern:**
```
docker compose run --rm backend bundle exec rspec spec/models/ --pattern "*license*"
```

**With detailed output:**
```
docker compose run --rm backend bundle exec rspec --format documentation
```

### Test Categories

#### Unit Tests
- **Models**: Database validations, relationships, business rules
- **Services**: Core business logic and calculations
- **Helpers**: Utility functions and formatting

#### Integration Tests
- **Controllers**: HTTP request/response handling
- **Database**: Migration and data integrity
- **SMTP**: Email functionality (mocked)
- **Authentication**: Login and session management

### Development Testing Workflow

**During development:**
```
# Quick feedback - run relevant tests only
docker compose run --rm backend bundle exec rspec spec/models/user_spec.rb

# Before committing - run full suite
docker compose run --rm backend bundle exec rspec
```

**Test-driven development:**
1. Write failing test
2. Implement minimal code to pass
3. Refactor and repeat

### Frontend Testing

**Current status:** No automated frontend tests implemented.

**Manual testing approach:**
- Browser-based testing through the web interface
- User acceptance testing with test credentials
- Cross-browser compatibility checks

> 💡 **Future enhancement**: Frontend testing with tools like Capybara or Selenium could be added.

### Test Environment

**Isolated test database:**
- Tests run against a separate test database
- Database is reset between test runs
- No interference with development data

**Test configuration:**
```
# Tests automatically use test environment
RACK_ENV=test docker compose run --rm backend bundle exec rspec
```

### Continuous Integration

**Automated testing:**
- Tests run automatically on code changes
- Must pass before deployment
- Prevents regression bugs in production

### Performance Considerations

Based on testing best practices, Licentra's test suite performance:

- **2-3 minutes**: Acceptable for comprehensive backend testing
- **400+ tests**: Thorough coverage of critical functionality
- **Docker isolation**: Consistent test environment across machines

**Optimization strategies:**
- Run specific test files during development
- Use full suite only before commits/deployment
- Parallel testing could reduce runtime (future enhancement)

### Troubleshooting Tests

**Tests failing unexpectedly:**
```
# Check test database connection
docker compose run --rm backend bundle exec rspec --dry-run

# Reset test environment
docker compose down
docker compose up -d db
docker compose run --rm backend bundle exec rspec
```

**Slow test performance:**
```
# Check Docker resources
docker stats

# Ensure adequate system resources
# Tests require database operations and can be I/O intensive
```

### Test Coverage

**What's tested:**
- ✅ Database models and validations
- ✅ Business logic and calculations
- ✅ User authentication and sessions
- ✅ License management workflows
- ✅ SMTP configuration and sending
- ✅ Input validation and security

**What's not tested:**
- ❌ Frontend JavaScript functionality
- ❌ CSS styling and responsive design
- ❌ Browser compatibility
- ❌ End-to-end user workflows

### Best Practices

1. **Run tests before committing** - Prevent broken code in repository
2. **Focus on critical paths** - Prioritize testing core business logic
3. **Keep tests fast** - Write efficient tests that run quickly
4. **Maintain test data** - Keep test fixtures up to date
5. **Document test scenarios** - Clear test descriptions and comments

---

*Next: [Contributing](#contributing) for contribution guidelines.*

## 🤝 Contributing

Licentra is currently a **university project** and not open for external contributions until project completion.

### Current Status

**Contribution policy:**
- **External contributions**: Not accepted during university project phase
- **Timeline**: Contributing will be opened after project completion
- **Reason**: Academic integrity and project evaluation requirements

### Future Contributions

Once the university project is completed, we plan to welcome contributions in areas such as:

- **Frontend testing implementation**
- **REST API development**
- **Additional authentication methods**
- **Performance optimizations**
- **Documentation improvements**
- **Bug fixes and security enhancements**

### Stay Updated

**Follow project progress:**
- **Repository**: [Project-FleX-PFX/Licentra](https://github.com/Project-FleX-PFX/Licentra)
- **Issues**: Monitor for future contribution opportunities
- **Releases**: Check for post-graduation open source release

> 💡 **Note**: We appreciate your interest and look forward to community contributions after project completion!

### Development Guidelines (Future)

When contributions are opened, we will follow these standards:

- **Code Style**: Ruby community standards
- **Testing**: All new features must include tests
- **Documentation**: Update README and inline documentation
- **Security**: Follow secure coding practices
- **Docker**: Maintain containerized architecture

---

## 📄 License

This project is licensed under the **MIT License**.

### MIT License

```
MIT License

Copyright (c) 2025 Project FleX (PFX)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```


### What This Means

**You are free to:**
- ✅ **Use** the software for any purpose
- ✅ **Modify** the source code
- ✅ **Distribute** copies of the software
- ✅ **Sublicense** and sell copies
- ✅ **Private use** for personal or commercial projects

**Requirements:**
- 📋 **Include copyright notice** in all copies
- 📋 **Include license text** in all copies

**Limitations:**
- ❌ **No warranty** - software provided "as is"
- ❌ **No liability** - authors not responsible for damages
- ❌ **No trademark rights** - license doesn't grant trademark use

### Why MIT License?

The MIT License was chosen because it:
- **Maximizes freedom** for users and developers
- **Minimal restrictions** while protecting authors
- **Business-friendly** for commercial use
- **Compatible** with most other open source licenses
- **Simple and clear** legal language

---

**Built with ❤️ using Ruby, Sinatra, PostgreSQL, and Docker**

*Thank you for your interest in Licentra!*

