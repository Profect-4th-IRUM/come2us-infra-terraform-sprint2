# ☁️ Come2us Terraform Infrastructure

> **Come2us e-commerce platform**의 AWS 인프라를 코드로 관리하기 위한 Terraform 레포지토리입니다.
> 본 저장소는 **MVP(1차)** → **MSA(2차)** → **고도화(3차)** 단계로 확장 가능한 구조를 목표로 설계되었습니다.

---

## 📦 프로젝트 개요

| 항목                     | 내용                                              |
| ---------------------- | ----------------------------------------------- |
| **Infra as Code Tool** | Terraform v1.9+                                 |
| **Cloud Provider**     | AWS (ap-northeast-2 / 서울 리전)                    |
| **구성 요소**              | VPC, Subnet, NAT, ECS, EC2, RDS, ElastiCache, ALB, Security Group |
| **아키텍처 타입**            | 단일 VPC, 2AZ 구성 (Public/Private)                 |
| **운영 전략**              | S3 + DynamoDB 원격 상태 관리        |

---

자세한 사항은 아래 링크 참조바랍니다.

[COME2US MSA 인프라 아키텍처 설계서](https://www.notion.so/goormkdx/Come2us-MSA-2a2c0ff4ce3180109a76cf3c1f45c424?source=copy_link)
