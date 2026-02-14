# Nebula API Quick Reference

All API endpoints support JSON and require the `Content-Type: application/json` header.

## Authentication

### Signup
```
POST /api/auth/signup
{
  "user": {
    "username": "john",
    "email": "john@example.com",
    "password": "password123",
    "password_confirmation": "password123"
  }
}

Response:
{
  "access_token": "tsid123456...",
  "user": {
    "id": "user123",
    "username": "john",
    "email": "john@example.com"
  }
}
```

### Login
```
POST /api/auth/login
{
  "username": "john",
  "password": "password123"
}

Response:
{
  "access_token": "tsid123456...",
  "user": {
    "id": "user123",
    "username": "john",
    "email": "john@example.com"
  }
}
```

### Logout
```
DELETE /api/auth/logout
Authorization: Bearer <token>

Response: 200 OK
```

### Get Current User
```
GET /api/me
Authorization: Bearer <token>

Response:
{
  "id": "user123",
  "username": "john",
  "email": "john@example.com",
  "is_admin": false
}
```

## Collections

### List Collections
```
GET /api/collections

Response:
[
  {
    "id": "col123",
    "alias": "myblog",
    "title": "My Blog",
    "description": "My personal blog",
    "public": true,
    "visibility": 0,
    "owner_id": "user123"
  }
]
```

### Create Collection
```
POST /api/collections
Authorization: Bearer <token>
{
  "collection": {
    "alias": "myblog",
    "title": "My Blog",
    "description": "My personal blog",
    "public": true,
    "visibility": 0
  }
}
```

### Get Collection
```
GET /api/collections/:alias

Response:
{
  "id": "col123",
  "alias": "myblog",
  "title": "My Blog",
  ...
}
```

### Update Collection
```
PATCH /api/collections/:alias
Authorization: Bearer <token>
{
  "collection": {
    "title": "Updated Title",
    "description": "Updated description"
  }
}
```

### Delete Collection
```
DELETE /api/collections/:alias
Authorization: Bearer <token>
```

## Posts

### Create Post
```
POST /api/posts
Authorization: Bearer <token>
{
  "post": {
    "title": "Hello World",
    "slug": "hello-world",
    "content": "This is my first post",
    "privacy": 0,
    "collection_id": "col123"
  }
}
```

### Get Post
```
GET /api/posts/:id
```

### Update Post
```
PATCH /api/posts/:id
Authorization: Bearer <token>
{
  "post": {
    "title": "Updated Title",
    "content": "Updated content"
  }
}
```

### Delete Post
```
DELETE /api/posts/:id
Authorization: Bearer <token>
```

## Collection Posts

### List Posts in Collection
```
GET /api/collections/:alias/posts

Response:
[
  {
    "id": "post123",
    "title": "Hello World",
    "slug": "hello-world",
    "content": "This is my first post",
    "owner_id": "user123",
    "collection_id": "col123"
  }
]
```

### Create Post in Collection
```
POST /api/collections/:alias/posts
Authorization: Bearer <token>
{
  "post": {
    "title": "Hello World",
    "slug": "hello-world",
    "content": "This is my first post"
  }
}
```

### Get Post from Collection
```
GET /api/collections/:alias/posts/:id
```

### Update Post in Collection
```
PATCH /api/collections/:alias/posts/:id
Authorization: Bearer <token>
```

## Email Subscriptions

### Subscribe to Collection
```
POST /api/collections/:alias/email/subscribe
{
  "email": "subscriber@example.com"
}

Response:
{
  "message": "Check your email to confirm subscription"
}
```

### Unsubscribe from Collection
```
DELETE /api/collections/:alias/email/unsubscribe?token=<token>

Response:
{
  "message": "Unsubscribed successfully"
}
```

### Confirm Subscription
```
GET /email/confirm/:token
```

## ActivityPub

### Inbox (Receive Activities)
```
POST /api/collections/:alias/inbox

Accepts:
- Follow activities (to request following)
- Undo activities (to unfollow)
- Like/Announce activities (engagement tracking)
```

### Outbox (Activity Feed)
```
GET /api/collections/:alias/outbox

Response: OrderedCollection with posts as activities
```

### Followers Collection
```
GET /api/collections/:alias/followers

Response: OrderedCollection of follower actor IDs
```

## OAuth

### Initiate OAuth Flow
```
POST /auth/oauth/:provider
{
  "provider": "github"  # or "google"
}

Redirects to provider's login page
```

### OAuth Callback (handled automatically)
```
GET /auth/oauth/:provider/callback?code=...&state=...

Automatically creates user and establishes session
```

## Password Reset

### Request Password Reset
```
POST /reset
{
  "email": "user@example.com"
}

Response: 200 OK (even if email doesn't exist)
```

### Reset Password
```
PATCH /reset/:token
{
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

## Admin

### Get Dashboard
```
GET /admin
Authorization required (admin user)

Response: HTML dashboard
```

### List Users
```
GET /admin/users
Authorization required (admin user)
```

### Get User
```
GET /admin/users/:id
Authorization required (admin user)
```

### Delete User
```
DELETE /admin/users/:id
Authorization required (admin user)
```

### Toggle Admin Status
```
PATCH /admin/users/:id/status
Authorization required (admin user)
```

## Privacy Levels

Posts can have different privacy levels:
- `0` = Public (visible to everyone)
- `1` = Friends only (visible to owner only)
- `2` = Private (visible to owner only)

## Common Response Codes

- `200 OK` - Success
- `201 Created` - Resource created
- `204 No Content` - Success with no response body
- `400 Bad Request` - Invalid input
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation failed

## Error Responses

```json
{
  "error": "Error message",
  "errors": ["Field error 1", "Field error 2"]
}
```

## Headers

All API requests should include:
```
Content-Type: application/json
Accept: application/json

For authenticated requests:
Authorization: Bearer <token>
```

## Rate Limiting

Not yet implemented - will be added in future updates.

## Webhooks

Not yet implemented - will be added in future updates.
