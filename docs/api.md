# MindVault V1 API

All endpoints use the `/api` prefix.

## Auth

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`

## Knowledge Bases

- `GET /api/knowledge-bases`
- `POST /api/knowledge-bases`
- `PUT /api/knowledge-bases/{id}`
- `DELETE /api/knowledge-bases/{id}`

## Nodes

- `GET /api/nodes/{knowledgeBaseId}`
- `POST /api/nodes`
- `PUT /api/nodes/{id}`
- `DELETE /api/nodes/{id}`

## Documents

- `GET /api/documents/{nodeId}`
- `POST /api/documents`
- `PUT /api/documents/{id}`
- `DELETE /api/documents/{id}`

## Search

- `GET /api/search?keyword=`

The scaffold exposes these paths as stable V1 contracts. Business logic will be filled in during feature implementation phases.
