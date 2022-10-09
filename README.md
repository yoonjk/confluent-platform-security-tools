Confluent Platform Security Tools
=================================

이 리포지토리에는 Kafka 키 저장소(keystore) 및 신뢰 저장소(truststore)를 생성하는 도구와 함께 키 저장소 및 신뢰 저장소를 Kafka에 배포하는 방법을 설명하는 다이어그램이 포함되어 있습니다.

여러 CA 또는 CA 대신 인증서를 사용하여 신뢰 저장소를 다른 방식으로 구성할 수 있습니다. 그러나 현재 스크립트는 이러한 추가 구성을 다루지 않습니다.

## User-input vs. Scripted Installation

- `kafka-generate-ssl.sh` - 사용자 입력을 요청합니다
- `kafka-generate-ssl-automatic.sh` - 스크립트를 실행전, 다음의 환경 변수를 설정해야 함 (example):
  - `COUNTRY`
  - `STATE`
  - `ORGANIZATION_UNIT`
  - `CITY`
  - `PASSWORD`

Example:
```
export COUNTRY=US
export STATE=IL
export ORGANIZATION_UNIT=SE
export CITY=Chicago
export PASSWORD=secret
bash ./kafka-generate-ssl-automatic.sh
```
1. CA 인증서 생성
```
  echo "OK, trust store 생성하고, root CA 개인키/공개키 생성."
  echo
  echo "첫번째 개인키(private)/공개키(pub) 생성."
  echo

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=$CN"
```
