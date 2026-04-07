# Glossary — 术语表（精简）

本文件收录课程中常见的核心术语与简短释义，供复习与查阅。

- VPC: Virtual Private Cloud，虚拟私有云，用于在 AWS 中隔离网络资源。
- Subnet: 子网，VPC 中的 IP 地址子范围（公有/私有子网）。
- AZ: Availability Zone，可用区，AWS 地理子单元，提供故障隔离。
- Region: 区域，一组可用区（AZ），如 `us-east-1`。
- EC2: 弹性计算（虚拟机）服务，提供可伸缩的服务器实例。
- AMI: Amazon Machine Image，EC2 实例镜像。
- EBS: Elastic Block Store，块存储，用于 EC2 持久磁盘。
- S3: Simple Storage Service，对象存储，按对象计费，提供高可用与低成本归档选项。
- IAM: Identity and Access Management，身份与访问管理，用于用户/角色/权限控制。
- Security Group: 实例级防火墙（有状态）。
- NACL: Network ACL，子网级访问控制列表（无状态）。
- ELB (ALB/NLB): 负载均衡器，用于分发流量（应用层/网络层）。
- RDS: 托管关系型数据库服务（支持 MySQL、Postgres、Aurora 等）。
- DynamoDB: 无服务器键值/文档数据库，低延迟并可水平扩展。
- Lambda: 无服务器函数计算，按调用计费。
- CloudFormation: 基于模板的基础设施即代码（IaC）。
- Route 53: DNS 与流量路由服务。
- CloudWatch: 监控与日志服务，包含指标、告警、Logs 与 Insights。
- KMS: Key Management Service，托管密钥与加密服务。
- VPC Endpoint: 私有链接服务，避免通过互联网访问 AWS 服务。
- SQS / SNS: 排队与通知服务，分别用于点对点与发布/订阅模式。

（更多术语会在需要时追加）
