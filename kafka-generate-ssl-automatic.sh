#!/usr/bin/env bash

set -eu

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

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -e "$KEYSTORE_WORKING_DIRECTORY" ]; then
  file_exists_and_exit $KEYSTORE_WORKING_DIRECTORY
fi

if [ -e "$CA_CERT_FILE" ]; then
  file_exists_and_exit $CA_CERT_FILE
fi

if [ -e "$KEYSTORE_SIGN_REQUEST" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST
fi

if [ -e "$KEYSTORE_SIGN_REQUEST_SRL" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST_SRL
fi

if [ -e "$KEYSTORE_SIGNED_CERT" ]; then
  file_exists_and_exit $KEYSTORE_SIGNED_CERT
fi

echo "Kafka SSL 키 저장소(keystore) 및 신뢰 저장소(truststore) 생성 스크립트에 오신 것을 환영합니다.."

trust_store_file=""
trust_store_private_key_file=""

  if [ -e "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
    file_exists_and_exit $TRUSTSTORE_WORKING_DIRECTORY
  fi

  mkdir $TRUSTSTORE_WORKING_DIRECTORY
  echo
  echo "OK, trust store 생성하고, root CA 개인키/공개키 생성."
  echo
  echo "첫번째 개인키(private)/공개키(pub) 생성."
  echo

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=$CN"

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

  echo
  echo "2개의 CA root 파일을 생성(pri/pub):"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-key -- 나중에 인증서에 서명하는 데 사용되는 개인키"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -- 이 인증서는 "
  echo "   truststore 에 저장되고 CA 인증서로서 역할을 합니다"
  echo "   일단 이 인증서가 truststore 에 저장되면, 현재 디렉토리에 있는 인증서는 백업 후 삭제되어야 됩니다(보안상)"
  echo "   그것은 다음에 의해 truststore에서 조회할 수 있습니다:"
  echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

  echo
  echo "이제 truststore를 생성하고, 인증서(CA public 인증서)를  반입(import)."
  echo

  keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
    -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/ca-cert \
    -noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS

  trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

  echo
  echo "$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME was created."

  # 인증서(CA public 인증서)가 truststore에 있기 때문에 더이상 local disk에 있을 필요가 없습니다.
  rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

echo
echo "계속해서:"
echo " - trust store 파일(jks): $trust_store_file"
echo " - trust store 개인키: $trust_store_private_key_file"

mkdir $KEYSTORE_WORKING_DIRECTORY

echo
echo "이제 키 저장소가 생성됩니다. "
echo "각 브로커와 클라이언트는 자신의 keystore를 가질 필요가 있습니다."
echo "keystore. 이 스크립트는 하나의 keystore만을 생성하는 스크립트입니다. 여러개의 keystore를 위해 
echo "스크립트를 반복해서 실행하세요"."
echo
echo "     참고: 참고: 현재 Kafka에서는 CN(일반 이름)이 이 호스트의 FQDN일 필요가 없습니다."
echo "          그러나 어느 시점에서 이것은 바뀔 수 있습니다. 따라서 CN을 FQDN으로 만듭니다."
echo "          일부 운영 체제는 CN 프롬프트로 '이름(first)/성(last name)'이라고 부릅니다."

# CN 및 FQDN에 대해 자세히 알아보려면, 다음을 참고하세요:
# https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html

keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
  -alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA \
   -noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS

echo
echo "'$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME' 이제 키 쌍과 자체 서명된 인증서가 포함됩니다."
echo "다시 말하지만, 이 키 저장소는 하나의 브로커 또는 하나의 논리적 클라이언트에만 사용할 수 있습니다"
echo "다른 브로커나 클라이언트는 자체 키 저장소를 생성해야 합니다."

echo
echo "신뢰 저장소(truststore)에서 인증서 가져와서 $CA_CERT_FILE에 저장."
echo

keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE -keypass $PASS -storepass $PASS

echo
echo "이제 키 저장소(keystore)에 대한 인증서 서명 요청(csr)이 만들어집니다."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -certreq -file $KEYSTORE_SIGN_REQUEST -keypass $PASS -storepass $PASS

echo
echo "이제 CA 인증서로 인증서에 서명합니다."
echo
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
  -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
  -days $VALIDITY_IN_DAYS -CAcreateserial
  
# 위에서 생성한 $KEYSTORE_SIGN_REQUEST_SRL 은 더이상 필요하거나 사용되지 않습니다.

echo
echo "이제 CA를 키 저장소(keystore)로 반입(import)합니다."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -import -file $CA_CERT_FILE -keypass $PASS -storepass $PASS -noprompt
  
rm $CA_CERT_FILE # 신뢰 저장소에 저장되어 있으므로 local에 있는 $CA_CERT_FILE 인증서를 삭제하십시오.

echo
echo "이제 키 저장소의 서명된 인증서를 다시 키 저장소로 반입(import)합니다."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -import \
  -file $KEYSTORE_SIGNED_CERT -keypass $PASS -storepass $PASS

echo
echo "모두 완료!"
echo
echo "작업중 생성한 파일을 삭제합니다. 그것들은:"
echo " - '$KEYSTORE_SIGN_REQUEST_SRL': CA serial number"
echo " - '$KEYSTORE_SIGN_REQUEST': 키 저장소의 인증서 서명 요청"
echo "   (that was fulfilled)"
echo " - '$KEYSTORE_SIGNED_CERT': 키저장서에 반입(import)한 CA에서 서명한 인증서 "
echo 

  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT
