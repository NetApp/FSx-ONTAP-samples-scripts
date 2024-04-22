# Generating Certficates on OSx

## Easy RSA

## Install Easy RSA using Homebrew

```bash
brew install easy-rsa
```

# Generate the Certificates and Keys with Easy RSA

## Start new PKI

```bash
easyrsa init-pki
```

## Build CA

```bash
easyrsa build-ca
```

## Generate Server Key and Certificate

```bash
easyrsa build-server-full UNIQUE_SERVER_SHORT_NAME nopass
```

## Generate Client Key(s) and Certificate(s)

```bash
easyrsa build-client-full UNIQUE_CLIENT_SHORT_NAME nopass
```

Note: inline auth files can be generated using Easy-TLS, details can be found at the bottom of the Easy-RSA v3 OpenVPN Howto page.

## Generate Diffie Hellman (DH) parameters

```bash
easyrsa gen-dh
```

## Generate ta.key for tls-auth (optional security hardening)

openvpn --genkey --secret ta.key

## Convert to PEM format

openssl x509 -in ca.crt -out ca.pem  
openssl x509 -in server.fsxn.crt -out server.fsxn.pem
openssl x509 -in client.fsxn.crt -out client.fsxn.pem

## Copy Certificates to Folders for OpenVPN

Create folders: one for the server, and one for each of the client’s configurations. Give each client config a unique name, these should match the names of the certificates generated for each client.

Then copy the following files from the pki folder to each of the following:

Note: Easy-rsa created the pki folder at this location on my Mac. Some of the files are in subfolders

/usr/local/etc/pki/
Server:

ca.crt
dh.pem
ta.key
server.crt
server.key
Client:

ca.crt
ta.key
client.crt
client.key
