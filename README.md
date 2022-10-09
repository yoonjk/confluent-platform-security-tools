Secure Kafka Cluster 구성을 위한 인증서 작성 순서
==========================================

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
openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
-out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS -nodes \
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=$CN"
```

2. CA 인증서를 truststore에 반입
```
keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
-alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/ca-cert \
-noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS
```

3. kafka broker 또는 producer/consumer에서 사용할 keystore 생성
```
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
-alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA \
-noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS
```
4. CA root 인증서를 keystore에 반입. Alias는 CARoot
```
keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE -keypass $PASS -storepass $PASS
```

5. 신뢰 저장소(truststore)에서 인증서 가져와서 $CA_CERT_FILE에 저장
```
keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE -keypass $PASS -storepass $PASS
```

6. 키 저장소(keystore)에 대한 인증서 서명 요청(csr) 파일 생성
```
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
-certreq -file $KEYSTORE_SIGN_REQUEST -keypass $PASS -storepass $PASS
```

7. Root CA 인증서로 인증서에 서명
```
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
-in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
-days $VALIDITY_IN_DAYS -CAcreateserial
```

8. Root CA 인증서를 alias가 CARoot로 설정하고, 키 저장소(keystore)로 반입(import)
```
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
-import -file $CA_CERT_FILE -keypass $PASS -storepass $PASS -noprompt
```  

9. 서명한 인증서를 다시 키 저장소로 반입(import)
``` 
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -import \
-file $KEYSTORE_SIGNED_CERT -keypass $PASS -storepass $PASS
``` 

10. RootCA 개인키는 백업, 작업중 생성한 인증서 파일 삭제
``` 
rm $KEYSTORE_SIGN_REQUEST_SRL
rm $KEYSTORE_SIGN_REQUEST
rm $KEYSTORE_SIGNED_CERT
``` 
