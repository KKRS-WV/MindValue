$env:JAVA_HOME = 'C:\path\to\jdk-21'
$env:MINDVAULT_DB_PASSWORD = 'your-postgres-password'
$env:Path = "$env:JAVA_HOME\bin;C:\path\to\postgresql\bin;$env:Path"

Write-Host "JAVA_HOME=$env:JAVA_HOME"
java -version
psql --version
