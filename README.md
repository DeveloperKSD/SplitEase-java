# SplitEase 💰

A multi-user expense tracker and bill-splitting application built with **Java Swing** and **Supabase** as the backend.

## Features

- **User Authentication** — Sign up and log in with email/password via Supabase Auth
- **Group Management** — Create groups, add members, and manage shared expenses
- **Expense Tracking** — Record expenses with automatic equal-split calculations
- **Balance Settlement** — View who owes whom and track debt across group members
- **Multi-User Sync** — Data is stored in Supabase with Row Level Security for per-user isolation
- **Modern UI** — Clean Java Swing interface with a dedicated auth screen

## Tech Stack

| Layer       | Technology                          |
|-------------|-------------------------------------|
| Language    | Java 17+                            |
| UI          | Java Swing                          |
| Backend     | Supabase (PostgreSQL + Auth + RLS)  |
| HTTP Client | OkHttp 4.12                         |
| JSON        | Gson 2.10.1                         |

## Project Structure

```
splitease/
├── src/
│   ├── splitease/
│   │   ├── auth/           # Supabase authentication (AuthUser, SupabaseAuth)
│   │   ├── controller/     # Business logic (GroupController, SupabaseClient)
│   │   ├── exception/      # Custom exceptions
│   │   ├── model/          # Data models (Group, Expense, SplitStrategy)
│   │   └── ui/             # Swing frames (AuthFrame, MainFrame)
│   ├── run.ps1             # PowerShell build & run script
│   └── run.bat             # Batch build & run script
├── properties/
│   ├── config.properties.example   # Template — copy and fill in your keys
│   └── config.properties           # Your local config (git-ignored)
├── lib/                    # JAR dependencies (git-ignored, see below)
├── supabase_setup.sql      # SQL schema & RLS policies for Supabase
├── compile_check.ps1       # Quick compilation check script
└── .gitignore
```

## Getting Started

### Prerequisites

- **Java 17** or later (`java -version` to check)
- A **Supabase** project ([supabase.com](https://supabase.com))

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/splitease.git
cd splitease
```

### 2. Download dependencies

Create a `lib/` directory and download the following JARs into it:

| JAR                        | Maven Central Link |
|----------------------------|--------------------|
| `okhttp-4.12.0.jar`       | [OkHttp](https://central.sonatype.com/artifact/com.squareup.okhttp3/okhttp/4.12.0) |
| `okio-jvm-3.6.0.jar`      | [Okio](https://central.sonatype.com/artifact/com.squareup.okio/okio-jvm/3.6.0) |
| `gson-2.10.1.jar`         | [Gson](https://central.sonatype.com/artifact/com.google.code.gson/gson/2.10.1) |
| `kotlin-stdlib-1.9.10.jar`| [Kotlin Stdlib](https://central.sonatype.com/artifact/org.jetbrains.kotlin/kotlin-stdlib/1.9.10) |

### 3. Set up Supabase

1. Create a new Supabase project
2. Run the SQL from `supabase_setup.sql` in the Supabase SQL Editor to create tables and RLS policies
3. Copy `properties/config.properties.example` to `properties/config.properties`
4. Fill in your Supabase project URL and anon key:
   ```properties
   supabase.url=https://YOUR_PROJECT_REF.supabase.co
   supabase.key=YOUR_SUPABASE_ANON_KEY
   ```

### 4. Build and run

**PowerShell:**
```powershell
.\src\run.ps1
```

**Command Prompt:**
```cmd
src\run.bat
```

## Database Schema

The Supabase database schema is defined in [`supabase_setup.sql`](supabase_setup.sql) and includes:

- **groups** — Group name, description, and creator
- **group_members** — Many-to-many relationship between users and groups
- **expenses** — Expense records linked to groups with payer and amount
- **expense_splits** — Individual split amounts per member per expense

All tables are protected with **Row Level Security** policies to ensure users can only access data for groups they belong to.

## License

This project is for educational purposes.
