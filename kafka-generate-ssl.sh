#!/usr/bin/env bash

set -e

KEYSTORE_FILENAME="kafka.keystore.jks"
VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="truststore"
KEYSTORE_WORKING_DIRECTORY="keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"

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

echo
echo "Kafka SSL 키 저장소(keystore) 및 신뢰 저장소(truststore) 생성 스크립트에 오신 것을 환영합니다."

echo
echo "먼저, 신뢰 저장소(truststore) 및 관련 개인 키(CA Root key)를 생성해야 합니다,"
echo "또는 이미 신뢰 저장소 파일 및 개인 키(CA Root)가 있습니까?"
echo
echo -n "신뢰 저장소(truststore) 및 관련 개인 키(CA Root key)를 생성해야 합니까?? [yn] "
read generate_trust_store

trust_store_file=""
trust_store_private_key_file=""

if [ "$generate_trust_store" == "y" ]; then
  if [ -e "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
    file_exists_and_exit $TRUSTSTORE_WORKING_DIRECTORY
  fi

  mkdir $TRUSTSTORE_WORKING_DIRECTORY
  echo
  echo "Ok!, 신뢰 저장소(truststore)와 관련 개인 키(CA Root Key)를 생성하겠습니다.."
  echo
  echo "우선, CA root key."
  echo
  echo "프롬프트가 출력될 것입니다.:"
  echo " - 개인 키의 암호입니다."
  echo " - CN(일반 이름)은 현재 중요하지 않습니다."

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
    -out $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -days $VALIDITY_IN_DAYS

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

  echo
  echo "2개의 파일이 생성됩니다.:"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-key -- 이 개인키는 나중에 인증서를"
  echo "   sign하기 위해 사용합니다."
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -- 이 인증서는"
  echo "   잠시후 신뢰저장소(truststore)에 저당되고, CA 인증서로서 역할합니다."
  echo "   일단 이 인증서가 신뢰저장소에 저장되면, 삭제되어야 할 것입니다."
  echo "   이것은 다음의 명령어로 조회할 수 있습니다.:"
  echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

  echo
  echo "이제 인증서를 신뢰 저장소에 반입(import)합니다."
  echo
  echo "프롬프트가 출력되면:"
  echo " - 신뢰저장소에 대한 비밀번호 (labeled 'keystore'). 이것은 꼭 기억해야함"
  echo " - 인증서를 반입하기 원하는 확인 작업입니다."

  keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
    -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

  trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

  echo
  echo "$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME 생성되었다."

  # 이 인증서는 신뢰저장소에 저장되었기 떄문에 local에 더이상 필요 없습니다.
  rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE
else
  echo
  echo -n "신뢰저장소의 파일의 경로(path). "
  read -e trust_store_file

  if ! [ -f $trust_store_file ]; then
    echo "$trust_store_file isn't a file. Exiting."
    exit 1
  fi

  echo -n "신뢰저장소의 private key 파일의 경로. "
  read -e trust_store_private_key_file

  if ! [ -f $trust_store_private_key_file ]; then
    echo "$trust_store_private_key_file isn't a file. Exiting."
    exit 1
  fi
fi

echo
echo "계속해서:"
echo " - 신뢰저장소 파일:        $trust_store_file"
echo " - 신뢰저장소의 개인키 파일: $trust_store_private_key_file"

mkdir $KEYSTORE_WORKING_DIRECTORY

echo
echo "지금 keystore를 생성. "
echo "각 kafka broker 또는 클라이언트는 자신의 keystore를 필요합니다."
echo "이 스크립트는 하나의 keystore를 생성합니다. 여러 개의 키저장소를 위해 "
echo "이 스크립트를 여러번 반복에서 실행하십시요."
echo
echo "다음의 프롬프트가 출력되면:"
echo " - keystore의 비밀번호. 꼭 기억해라."
echo " - Personal information, such as your name."
echo "     참고: 현재 Kafka에서는 CN(일반 이름)이 이 호스트의 FQDN일 필요가 없습니다. "
echo "           그러나 어느 시점에서 이것은 바뀔 수 있습니다."
echo "           일부 운영 체제는 CN 프롬프트를 '이름(firstname)/성(lastname)으로 부릅니다."
echo " - 비밀번호, 키스토어(keystore)에 저장하기 위해. 이것은 반드시 기억해라!."

# To learn more about CNs and FQDNs, read:
# https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html

keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
  -alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA

echo
echo "'$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME' 키 패어와"
echo "self-signed 인증서를 포함합니다. 다시 말해 이 인증서는 하나의 kafka broker에 의해 사용되거나"
echo "하나의 클라이언트에서 사용됩니다. 다른 kafka broker나 클라이언트는 자신의 키저장소를 생성 해야합니다."

echo
echo "신뢰저장소에서 인증서를 반출해서 $CA_CERT_FILE로 저장합니다."
echo
echo "신뢰 저장소에 대한 비밀번호 프롬프트가 표시될 것입니다. (labeled 'keystore')"

keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE

echo
echo "이제 인증서 요청파일이 만들어 질 것입니다."
echo
echo "키저장소의 비밀번호 프롬프트가 표시될 것입니다."
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -certreq -file $KEYSTORE_SIGN_REQUEST

echo
echo "지금 CA Root key와 인증서로 kafka broker 또는 클라이언트에서 사용할 인증서를 sign합니다."
echo
echo "CA root Key에 대한 비밀번호 프롬프트가 나타날 것입니다."
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
  -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
  -days $VALIDITY_IN_DAYS -CAcreateserial
# 생성한 $KEYSTORE_SIGN_REQUEST_SRL은 더이상 사용되지 않습니다.

echo
echo "지금 CA 인증서가 keystore에 반입될 것입니다."
echo
echo "키저장소의 비밀번호 프롬프트가 표시될 것이며, import하기 원하는지 다시 확인 프롬프트가 표시될 것입니다."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -import -file $CA_CERT_FILE
rm $CA_CERT_FILE # 이 인증서는 신뢰저장소(truststore)에 저장되어 있기 때문에 삭제합니다.

echo
echo "CA Root 인증서는 키저장소(keystore)에 반입되었습니다."
echo
echo "키저장소의 비밀번호 프롬프트."
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -import \
  -file $KEYSTORE_SIGNED_CERT

echo
echo "모두 완료!"
echo
echo "중간 작업파일들을 삭제? 삭제 파일은:"
echo " - '$KEYSTORE_SIGN_REQUEST_SRL': CA serial number"
echo " - '$KEYSTORE_SIGN_REQUEST': 키저장소의 CSR 파일"
echo " - '$KEYSTORE_SIGNED_CERT': 키저장소의 인증서, CA에 sign하고 keystore에 반입한 것"
echo 
echo -n "삭제? [yn] "
read delete_intermediate_files

if [ "$delete_intermediate_files" == "y" ]; then
  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT
fi
