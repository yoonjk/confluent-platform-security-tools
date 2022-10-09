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
```
KEYSTORE_FILENAME="kafka.keystore.jks"
VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="truststore"
KEYSTORE_WORKING_DIRECTORY="keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"

COUNTRY=$COUNTRY
STATE=$STATE
OU=$ORGANIZATION_UNIT
CN=`hostname -f`
LOCATION=$CITY
PASS=$PASSWORD
```
