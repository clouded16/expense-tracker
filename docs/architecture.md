# System Architecture

## Overview
This project is a personal expense management system designed to help users
log expenses easily and understand their spending behavior through clear insights.

The system is split into three main parts:
- Mobile Application
- Backend Server
- Database

Each part has a clear responsibility to ensure reliability, transparency,
and ease of maintenance.

## System Components

### Mobile Application
The mobile application is responsible for:
- Collecting user input
- Accessing device features such as camera and SMS
- Displaying expenses and insights
- Sending confirmed data to the backend server

The mobile app does not perform heavy analysis or make financial decisions.

### Backend Server
The backend server is responsible for:
- Validating incoming data
- Storing expense records
- Analyzing spending patterns
- Generating personalized and explainable insights

The backend acts as the main decision-making component of the system.

### Database
The database is responsible for:
- Persistently storing users, expenses, insights, and feedback
- Preserving historical data
- Ensuring expense records are not silently modified or deleted

## Data Flow
1. The user inputs expense data through the mobile app
2. Automatic inputs (receipt or SMS) require user confirmation
3. Confirmed data is sent to the backend server
4. The backend stores the data in the database
5. Insights are generated based on stored data
6. The mobile app displays insights to the user

## Design Principles
- User confirmation is required before saving expenses
- The backend is the single source of truth
- Automation assists the user but never replaces user control
- The system must remain functional even if automation fails
