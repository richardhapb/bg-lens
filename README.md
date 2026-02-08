# BgLens - Background Check API

A Rails API for toy background checks that demonstrates production patterns including state machines, async processing, webhooks, and idempotent requests.

> **Note**: This is a portfolio project built for learning and demonstrating Rails patterns used in production background check systems.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Design Patterns](#design-patterns)
- [Getting Started](#getting-started)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Key Concepts](#key-concepts)
- [Project Structure](#project-structure)

---

## Overview

BgLens is a background check API that accepts candidate information, initiates various background checks (criminal, employment, education), processes them asynchronously, and delivers results via webhooks.

### Features

- RESTful API for creating and querying background checks
- Asynchronous processing with Sidekiq
- State machine for report lifecycle management
- Strategy pattern for extensible check types
- Idempotent request handling
- Webhook delivery with retry logic
- Comprehensive test suite

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              API Layer                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  POST /api/v1/background_checks   GET /api/v1/background_checks/:id │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Service Layer                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              CreateBackgroundCheckService                           │    │
│  │  - Idempotency check                                                │    │
│  │  - Candidate creation/lookup                                        │    │
│  │  - Report & checks creation                                         │    │
│  │  - Job enqueueing                                                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Background Jobs (Sidekiq)                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐   │
│  │ ProcessReportJob │──│ ProcessCheckJob  │  │ WebhookDeliveryJob       │   │
│  │                  │  │                  │  │                          │   │
│  │ Orchestrates     │  │ Executes single  │  │ Delivers webhooks        │   │
│  │ report processing│  │ check via        │  │ with exponential backoff │   │
│  │                  │  │ strategy         │  │                          │   │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Strategy Layer                                     │
│  ┌─────────────────────┐ ┌────────────────────┐ ┌────────────────────────┐  │
│  │CriminalCheckStrategy│ │EmploymentCheck     │ │EducationCheckStrategy  │  │
│  │                     │ │Strategy            │ │                        │  │
│  │ Court records API   │ │ Employment verify  │ │ Degree verification    │  │
│  └─────────────────────┘ └────────────────────┘ └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Data Layer                                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────────────────────────┐  │
│  │Candidate │  │  Report  │  │  Check   │  │      WebhookDelivery        │  │
│  │          │──│ (AASM)   │──│          │  │                             │  │
│  │          │  │          │──│          │  │                             │  │
│  └──────────┘  └──────────┘  └──────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Request** → API receives background check request with candidate info
2. **Idempotency** → Service checks for existing report with same idempotency key
3. **Creation** → Creates candidate (or finds existing), report, and check records
4. **Enqueue** → Enqueues `ProcessReportJob` for async processing
5. **Processing** → Job transitions report to `processing`, executes each check
6. **Strategies** → Each check delegates to appropriate strategy (criminal, employment, education)
7. **Completion** → When all checks complete, report transitions to `completed`
8. **Webhook** → `WebhookDeliveryJob` sends results to registered webhook URL

---

## Design Patterns

### 1. State Machine (AASM)

The `Report` model uses AASM for lifecycle management:

```ruby
aasm column: 'status' do
  state :pending, initial: true
  state :processing
  state :completed
  state :failed

  event :start_processing do
    transitions from: :pending, to: :processing
  end

  event :complete do
    transitions from: :processing, to: :completed,
                guard: :all_checks_completed?
    after do
      update(completed_at: Time.current)
      trigger_webhooks
    end
  end
end
```

**Why?** State machines enforce valid transitions, prevent invalid states, and centralize lifecycle logic.

### 2. Strategy Pattern

Check processing is delegated to strategy classes:

```ruby
# app/models/check.rb
def check_strategy
  case check_type
  when 'criminal' then CriminalCheckStrategy.new
  when 'employment' then EmploymentCheckStrategy.new
  when 'education' then EducationCheckStrategy.new
  end
end
```

**Why?** New check types can be added without modifying existing code (Open/Closed Principle).

### 3. Service Object Pattern

Business logic is encapsulated in service objects:

```ruby
# app/services/create_background_check_service.rb
class CreateBackgroundCheckService
  def call
    existing_report = Report.find_by(idempotency_key: idempotency_key)
    return Result.success(existing_report) if existing_report

    ActiveRecord::Base.transaction do
      candidate = find_or_create_candidate
      report = create_report(candidate)
      create_checks(report)
      # ...
      Result.success(report)
    end
  rescue => e
    Result.failure([e.message])
  end
end
```

**Why?** Keeps controllers thin, makes business logic testable, and provides clear boundaries.

### 4. Result Object Pattern

Service objects return result objects instead of raising exceptions:

```ruby
class Result
  attr_reader :data, :errors

  def self.success(data)
    new(success: true, data: data)
  end

  def self.failure(errors)
    new(success: false, errors: Array(errors))
  end

  def success?
    @success
  end
end
```

**Why?** Makes error handling explicit and avoids exception-based control flow.

### 5. Idempotency Pattern

Duplicate requests return the same result:

```ruby
# Controller extracts idempotency key from header
def idempotency_key
  request.headers['Idempotency-Key'] || SecureRandom.uuid
end

# Service checks for existing report
existing_report = Report.find_by(idempotency_key: idempotency_key)
return Result.success(existing_report) if existing_report
```

**Why?** Prevents duplicate processing when clients retry requests.

---

## Getting Started

### Prerequisites

- Ruby 3.2+
- PostgreSQL 14+
- Redis 6+

### Installation

```bash
# Clone the repository
git clone git@github.com:richardhapbb/bg-lens
cd bg-lens

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Run tests to verify setup
bundle exec rspec
```

### Configuration

Update `config/database.yml` with your PostgreSQL credentials:

```yaml
default: &default
  adapter: postgresql
  host: localhost
  port: 5432
  username: postgres
  password: postgres
```

### Running the Application

You need three terminal windows:

```bash
# Terminal 1: Start Redis
redis-server

# Terminal 2: Start Sidekiq
bundle exec sidekiq

# Terminal 3: Start Rails server
rails server
```

The API will be available at `http://localhost:3000`.

---

## API Documentation

### Create Background Check

```
POST /api/v1/background_checks
```

**Headers:**
| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | Must be `application/json` |
| `Idempotency-Key` | No | Unique key for idempotent requests |

**Request Body:**
```json
{
  "candidate": {
    "name": "John Doe",
    "ssn": "123-45-6789",
    "dob": "1990-01-15",
    "email": "john.doe@example.com"
  },
  "check_types": ["criminal", "employment", "education"],
  "webhook_url": "https://your-app.com/webhooks/background-checks"
}
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `candidate.name` | string | Yes | Full name of the candidate |
| `candidate.ssn` | string | Yes | Social Security Number (unique identifier) |
| `candidate.dob` | date | Yes | Date of birth (YYYY-MM-DD) |
| `candidate.email` | string | Yes | Email address |
| `check_types` | array | No | Types of checks to run. Default: `["criminal", "employment"]` |
| `webhook_url` | string | No | URL to receive webhook when report completes |

**Response (201 Created):**
```json
{
  "id": 1,
  "status": "pending",
  "idempotency_key": "550e8400-e29b-41d4-a716-446655440000",
  "candidate": {
    "id": 1,
    "name": "John Doe",
    "email": "john.doe@example.com"
  },
  "checks": [
    {
      "id": 1,
      "type": "criminal",
      "status": "pending",
      "result": null,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    },
    {
      "id": 2,
      "type": "employment",
      "status": "pending",
      "result": null,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ],
  "completed_at": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

**Error Response (422 Unprocessable Entity):**
```json
{
  "errors": ["Name can't be blank", "Ssn can't be blank"]
}
```

### Get Background Check

```
GET /api/v1/background_checks/:id
```

**Response (200 OK):**
```json
{
  "id": 1,
  "status": "completed",
  "idempotency_key": "550e8400-e29b-41d4-a716-446655440000",
  "candidate": {
    "id": 1,
    "name": "John Doe",
    "email": "john.doe@example.com"
  },
  "checks": [
    {
      "id": 1,
      "type": "criminal",
      "status": "completed",
      "result": {
        "records_found": 0,
        "offenses": [],
        "checked_at": "2024-01-15T10:31:00Z"
      },
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:31:00Z"
    },
    {
      "id": 2,
      "type": "employment",
      "status": "completed",
      "result": {
        "verified": true,
        "previous_employers": 3,
        "discrepancies": [],
        "checked_at": "2024-01-15T10:31:30Z"
      },
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:31:30Z"
    }
  ],
  "completed_at": "2024-01-15T10:31:30Z",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:31:30Z"
}
```

**Error Response (404 Not Found):**
```json
{
  "error": "Report not found"
}
```

### Webhook Payload

When a report completes, the following payload is sent to the registered `webhook_url`:

```json
{
  "report_id": 1,
  "status": "completed",
  "completed_at": "2024-01-15T10:31:30Z",
  "candidate": {
    "name": "John Doe",
    "email": "john.doe@example.com"
  },
  "checks": [
    {
      "type": "criminal",
      "status": "completed",
      "result": {
        "records_found": 0,
        "offenses": [],
        "checked_at": "2024-01-15T10:31:00Z"
      }
    }
  ]
}
```

**Headers sent with webhook:**
- `Content-Type: application/json`
- `X-Webhook-Signature: <HMAC-SHA256 signature>`

---

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/models/report_spec.rb

# Run specific test
bundle exec rspec spec/models/report_spec.rb:25
```

---

## Key Concepts

### Report States

```
┌─────────┐     start_processing!     ┌────────────┐
│ PENDING │ ────────────────────────► │ PROCESSING │
└─────────┘                           └────────────┘
     │                                      │
     │ mark_failed!                         │ complete! (when all checks done)
     │                                      │
     ▼                                      ▼
┌─────────┐                           ┌───────────┐
│ FAILED  │ ◄──── mark_failed! ────── │ COMPLETED │
└─────────┘                           └───────────┘
```

### Check Types

| Type | Description | Mock Response |
|------|-------------|---------------|
| `criminal` | Court records search | Records found, offenses list |
| `employment` | Employment verification | Verified status, employer count |
| `education` | Degree verification | Degree verified, institution |

### Retry Strategy

Jobs use exponential backoff for retries:

```ruby
class ProcessCheckJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
end

class WebhookDeliveryJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
end
```

---

## Project Structure

```
bg-lens/
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   │       └── background_checks_controller.rb
│   ├── jobs/
│   │   ├── process_check_job.rb
│   │   ├── process_report_job.rb
│   │   └── webhook_delivery_job.rb
│   ├── models/
│   │   ├── candidate.rb
│   │   ├── check.rb
│   │   ├── report.rb
│   │   └── webhook_delivery.rb
│   ├── serializers/
│   │   └── report_serializer.rb
│   ├── services/
│   │   └── create_background_check_service.rb
│   └── strategies/
│       ├── criminal_check_strategy.rb
│       ├── education_check_strategy.rb
│       └── employment_check_strategy.rb
├── config/
│   ├── routes.rb
│   └── initializers/
│       └── sidekiq.rb
├── db/
│   └── migrate/
│       ├── create_candidates.rb
│       ├── create_reports.rb
│       ├── create_checks.rb
│       └── create_webhook_deliveries.rb
└── spec/
    ├── factories/
    ├── models/
    ├── requests/
    └── services/
```

---

## Future Implementations Required

- [ ] Add circuit breaker for external API calls
- [ ] Implement rate limiting
- [ ] Add API authentication (JWT/API keys)
- [ ] Add pagination for listing reports
- [ ] Implement report cancellation
- [ ] Add Swagger/OpenAPI documentation
- [ ] Add real external API integrations
- [ ] Implement background check adjudication logic

---

## License

MIT
