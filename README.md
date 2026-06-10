# MindVault

> Graph-first personal knowledge management system.  
> 一个以知识图谱为第一入口的个人知识管理工具。

MindVault 是一个面向个人知识沉淀、浏览和组织的知识管理系统。它不以传统目录树作为核心交互，而是通过中心发散式知识地图来承载知识库、节点和 Markdown 文档，让用户从“知识之间的关系”出发进行探索。

V1 阶段不包含 AI、团队协作、向量数据库、OCR、PDF 解析等能力，重点验证一个核心假设：

**用户是否愿意通过知识地图，而不是目录树，来管理自己的知识。**

## 项目截图

当前仓库暂未提交截图。建议后续补充：

- 知识库首页
- 图谱工作区
- Markdown 文档面板
- 地图视图 / 传统视图切换

## 核心特性

- **Graph First**：知识地图是第一入口，文档是节点的附属内容。
- **知识库管理**：创建、编辑、删除个人知识库。
- **节点管理**：支持无限层级节点、标题修改、删除、拖拽定位。
- **动态图谱浏览**：支持缩放、平移、节点聚焦、曲线连线和地图式滚轮缩放。
- **Markdown 文档**：每个节点关联一篇 Markdown 文档，支持预览和编辑。
- **全局搜索**：搜索节点标题、节点描述、文档标题和文档内容。
- **视图切换**：支持图谱视图和传统层级视图，兼顾探索和整理。
- **用户资料页**：支持基础个人信息展示和编辑入口。

## 技术栈

### Frontend

- Flutter
- Material Design 3
- Riverpod
- GoRouter
- Dio
- Flutter Markdown

### Backend

- Spring Boot 3
- Java 21
- Spring Web
- Spring Security
- JWT Authentication
- Spring Data JPA
- Hibernate

### Database

- PostgreSQL 16

## 仓库结构

```text
.
├── backend/       # Spring Boot 单体后端 API
├── frontend/      # Flutter 跨端客户端
├── docs/          # PRD、API、开发说明
├── scripts/       # 本地开发辅助脚本
└── README.md
```

## 本地开发

### 环境要求

- Java 21
- Maven 3.9+
- Flutter SDK
- Android Studio / Android SDK
- PostgreSQL 16

### 初始化数据库

创建本地数据库：

```sql
CREATE DATABASE mindvault;
```

后端默认连接：

- Host: `localhost`
- Port: `5432`
- Database: `mindvault`
- Username: `postgres`
- Password: 通过环境变量 `MINDVAULT_DB_PASSWORD` 注入

### 配置本地环境脚本

本地脚本可能包含绝对路径和数据库密码，因此不会提交到 Git。

首次使用时复制示例文件：

```powershell
Copy-Item .\scripts\backend-env.example.ps1 .\scripts\backend-env.ps1
Copy-Item .\scripts\flutter-env.example.ps1 .\scripts\flutter-env.ps1
```

然后按你的机器环境修改：

- `scripts/backend-env.ps1`
- `scripts/flutter-env.ps1`

## 启动项目

### 启动后端

```powershell
.\scripts\run-backend.ps1
```

默认 API 地址：

```text
http://localhost:8080/api
```

### 启动前端

```powershell
cd frontend
..\scripts\flutter-env.ps1
flutter pub get
flutter run -d edge
```

如果使用 Chrome，也可以改为：

```powershell
flutter run -d chrome
```

## 测试

### Backend

```powershell
cd backend
mvn test
```

### Frontend

```powershell
cd frontend
flutter analyze
flutter test
```

### API Smoke Test

后端启动后，可运行：

```powershell
.\scripts\api-smoke.ps1
```

## 当前状态

MindVault 当前处于 V1/V1.1 原型验证阶段，核心功能已经覆盖：

- 用户注册 / 登录 / JWT 认证
- 知识库 CRUD
- 节点 CRUD
- 节点拖拽与位置保存
- Markdown 文档创建、编辑、预览
- 图谱工作区
- 地图式滚轮缩放
- 图谱视图与传统视图切换
- 搜索并定位节点

下一阶段重点会放在：

- 大规模节点下的图谱布局体验
- 聚焦模式和节点展开/折叠体验
- 文档阅读体验
- 数据导入导出
- 更稳定的跨端交互细节

## 产品原则

MindVault 的 V1 设计遵循以下原则：

1. **知识地图是第一入口**
2. **文档是节点的附属内容**
3. **优先保证探索体验，而不是流程图绘制能力**
4. **不在 V1 引入 AI、团队协作或复杂权限系统**
5. **保持单体架构，避免过早工程复杂化**

## V1 暂不包含

- AI 问答
- RAG
- 向量数据库
- OpenAI 集成
- OCR
- PDF 解析
- 团队协作
- 分享链接
- 消息通知
- 微服务
- Redis
- Elasticsearch

## License

本项目基于 [MIT License](./LICENSE) 开源。
