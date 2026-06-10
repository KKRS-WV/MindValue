param(
  [string]$BaseUrl = 'http://localhost:8080/api'
)

$email = "demo-$([DateTimeOffset]::Now.ToUnixTimeSeconds())@mindvault.local"
$password = 'password123'

$auth = Invoke-RestMethod -Method Post -Uri "$BaseUrl/auth/register" -ContentType 'application/json' -Body (@{
  username = 'Demo User'
  email = $email
  password = $password
} | ConvertTo-Json)

$headers = @{ Authorization = "Bearer $($auth.token)" }

$kb = Invoke-RestMethod -Method Post -Uri "$BaseUrl/knowledge-bases" -Headers $headers -ContentType 'application/json' -Body (@{
  name = 'AI'
  description = 'Prompt, RAG, Agent, LangChain'
  icon = 'hub'
} | ConvertTo-Json)

$nodes = Invoke-RestMethod -Method Get -Uri "$BaseUrl/nodes/$($kb.id)" -Headers $headers
$rag = $nodes | Where-Object { $_.title -eq 'RAG' } | Select-Object -First 1

$document = Invoke-RestMethod -Method Post -Uri "$BaseUrl/documents" -Headers $headers -ContentType 'application/json' -Body (@{
  nodeId = $rag.id
  title = 'RAG Notes'
  content = "# RAG`n`nChunking, embedding, and retrieval."
} | ConvertTo-Json)

$search = Invoke-RestMethod -Method Get -Uri "$BaseUrl/search?keyword=Chunking" -Headers $headers

[PSCustomObject]@{
  email = $email
  knowledgeBaseId = $kb.id
  nodeCount = $nodes.Count
  documentId = $document.id
  firstSearchNodeId = $search[0].nodeId
}
