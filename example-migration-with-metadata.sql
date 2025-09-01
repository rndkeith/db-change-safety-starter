/*---
change_id: V001
title: Create initial user management schema
ticket: AUTH-001
risk: medium
change_type: additive
backward_compatible: true
requires_backfill: false
owner: backend-team@company.com
reviewers: ["dba@company.com", "security@company.com"]
rollout_plan: "Deploy during maintenance window, no downtime expected"
rollback_plan: "Drop all tables created by this migration if issues arise"
---*/

-- Create users table
CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50) NOT NULL UNIQUE,
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_active BIT DEFAULT 1
);

-- Create user roles table
CREATE TABLE user_roles (
    id INT IDENTITY(1,1) PRIMARY KEY,
    role_name NVARCHAR(50) NOT NULL UNIQUE,
    description NVARCHAR(255),
    created_at DATETIME2 DEFAULT GETUTCDATE()
);

-- Create user role assignments table
CREATE TABLE user_role_assignments (
    id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    assigned_at DATETIME2 DEFAULT GETUTCDATE(),
    assigned_by INT,
    CONSTRAINT FK_UserRoleAssignments_Users FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT FK_UserRoleAssignments_Roles FOREIGN KEY (role_id) REFERENCES user_roles(id),
    CONSTRAINT FK_UserRoleAssignments_AssignedBy FOREIGN KEY (assigned_by) REFERENCES users(id)
);

-- Create indexes for performance
CREATE INDEX IX_Users_Email ON users(email);
CREATE INDEX IX_Users_Username ON users(username);
CREATE INDEX IX_UserRoleAssignments_UserId ON user_role_assignments(user_id);
CREATE INDEX IX_UserRoleAssignments_RoleId ON user_role_assignments(role_id);
