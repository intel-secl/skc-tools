OPENSSL=openssl
OUTDIR=./output
INDIR=./input

mkdir -p $OUTDIR
mkdir -p $INDIR

rm $OUTDIR/*.cert
rm $OUTDIR/*.key
rm $OUTDIR/*.csr

CA_CONF_PATH=$INDIR/ca.cnf
CA_ROOT_CERT=$OUTDIR/root.cert
SERVER_CERT=$OUTDIR/server.cert
SERVER_KEY=$OUTDIR/server.key
SERVER_PKCS8_KEY=$OUTDIR/server_pkcs8.key

CN="Test RSA Root" $OPENSSL req -config ${CA_CONF_PATH} -x509 -nodes \
        -keyout ${CA_ROOT_CERT} -out ${CA_ROOT_CERT} -newkey rsa:2048 -days 3650

# EE RSA certificates: create request first
CN="localhost" $OPENSSL req -config ${CA_CONF_PATH} -nodes \
        -keyout ${SERVER_KEY} -out ${OUTDIR}/req.csr -newkey rsa:2048

# Sign request: end entity extensions
$OPENSSL x509 -req -in ${OUTDIR}/req.csr -CA ${CA_ROOT_CERT} -days 3600 \
        -extfile ${CA_CONF_PATH} -extensions usr_cert -CAcreateserial >> ${SERVER_CERT}

$OPENSSL pkcs8 -topk8 -nocrypt -in ${SERVER_KEY} -out ${SERVER_PKCS8_KEY}

cat ${SERVER_PKCS8_KEY} | tr '\r\n' '@' | sed -e 's/@/\\n/g' > $OUTDIR/.key 
