#!/bin/bash
#
# Set the ARN of the secret that should contain just the password for the ONTAP admin user set below.
SECRET_ARN=""
#
# Set the FSx admin IP.
FSXN_ADMIN_IP=""
#
# Set the name of the volume to be created on the FSx for ONTAP file system. Note, volume names cannot have dashes in them.
VOLUME_NAME=""
#
# Set the volume size in GB. It should just be a number, without the 'GB' suffix.
VOLUME_SIZE=
#
# Set the SVM name. The default is 'fsx'.
SVM_NAME="fsx"
#
# Set the ONTAP admin user. The default is fsxadmin.
ONTAP_USER="fsxadmin"
#
################################################################################
# ****  You should not need to edit anything below this line ****
################################################################################
#
# When called from the CloudFormation template, the parameters are passsed as
# arguments.
SECRET_ARN="${SECRET_ARN:=$1}"
FSXN_ADMIN_IP="${FSXN_ADMIN_IP:=$2}"
VOLUME_NAME="${VOLUME_NAME:=$3}"
VOLUME_SIZE="${VOLUME_SIZE:=$4}"
SVM_NAME="${5:-$SVM_NAME}"
ONTAP_USER="${6:-$ONTAP_USER}"
#
# Since AWS only allows up to 16KB for the user data script, the rest of this script
# will be the compressed version of the linux_userData_real.sh file, which will be
# uncompressed and executed on the EC2 instance when it is deployed.
cat <<EOF2 > /tmp/linux_userData.sh
#!/bin/bash
export SECRET_ARN="$SECRET_ARN"
export FSXN_ADMIN_IP="$FSXN_ADMIN_IP"
export VOLUME_NAME="$VOLUME_NAME"
export VOLUME_SIZE="$VOLUME_SIZE"
export SVM_NAME="$SVM_NAME"
export ONTAP_USER="$ONTAP_USER"
EOF2

cat <<EOF3 | base64 -d | gunzip >> /tmp/linux_userData.sh
H4sIAAAAAAAAA91c+1fbxrP/XX/FVlExpEiyaZJv49bJ8RecxOeax8GQ5ntLro+Q1kZFlhQ9AIf4
f78zuytpJUtguCQ95/a0CexjZnbmM499qM9+Ms9d3zy34gvlmfKMjF3fpsSdEus6Ji7868eJ5XnU
IW5CZgHFliQgZhpHphfYlofTDeWof/Khp93iX8tuuVNRRofvJ++Go0HPvLKwY2a6sR27uqBtQIty
MtwfHJ6e9F4yKd7ThCQXlByaYzJy/fSGOG6cRO55mrgBsDOISRPbDGI9oh61YqrY8AdRteGeCgIq
hFjzr/43m4Ks8bfognpb0EbI4Xhy8p+jQQ9bfv8dmtLz1E/Sbw49dy2/PIa3sVHPeQ+1LwKinvqX
fnDtwziSLELaJS3g2jJU8uYN0bKl8vE3oLMOUKCxZSvKjCZjakc0+Wh5Kd3cIrcwKmYtEyvye1oH
fh8Pdo8HJ5OP/dHpoKdqm2gGPiaeW741oxEBOjpv0q+QEjlj3PSs0XVAEQVdNe//ktJoQVpciDGo
05+18s4gTcIUtE5vki1VgUbAwF9Ee0t0n5I2+fw7GsSX9PDOchEWAAagFrn0ijKTccZkGgVz0Ewh
Rmub9M+DKAGmhiqpB36cuspSARDs0ziGFQrNcC7apmMldIvoROtUVLxU7AtqX+4Gc9CMI2Y1S10w
AKodMmXiG1WhDDP1M1yCS6zKaTnOqe8EZa4xKEJ3idpxUcoShaUysubnjjWIoiB6Bzx7qpnMQ9Nj
rROKzegBqhh3TOMw8GO6OjQSPcbfceCriutfBZeUTxJiIFj4YMJ7c+tOU99G19F9aw7rB3t0YXCX
D+5qt/0/x5Pjwfvh4cGy+6/Obzv/+vXFy5cvXv3azSZ2IxpyRenzwHeTANGjOxA2zgMrcvQUFVtA
LbQWXmAhEEf9/X/v9SdH/f+MDvt7xQjbc3WIDla00KdBNLcSElnXEBJ0CEX01QvEoxirrSqG7LzR
KmoFRUf0S+pG1NmdO3FPtdPIA1N8dUPy9xdybpObGwe0hvhQNeHkKun1iIrRQJWwskjnJA0Rd0Rf
wO8yzIha9CJiQHZizyE6+kST+f9OnIBJDwx/IraYrF8RDUdvvCGmQ69MP/U8CaJlkA45iEDPbJIq
hogVYAuT/u8vagnn+M8z8g7kOv4wGJm7EAMPx9tZIEddMN8cHA1GBI0aozEX+VRcXjZWXxAaUi8P
stmYskKEnKWhTC8gmZgCnlNLHVeh3EVTXnjZ87ghIjoPrmhGio9kzJzAp3kU43nhJ1AWpoWyuhhM
9JhcJEkYd00T3AKgaVhz62vgwy8G2E406vSG6h6mI/3mt1eTVy8MBJceEN59tYO/M6IcdvqX1R4D
aZlCBawlmhM94vm2MhoWQr06wPLUJK/DChMd8kIGWwleBHxlo/OPIDUT6qkMntG72+jfxaRNBq2a
s8mYIJ4yOj2YjIf/PehpmxCNdI/88ccfRG0br9vPtY+Ho9P9AetWyRYbetDfh6G3ogd/W060zU3t
uH+wd7j/8+brdnvrlw78saUoPFc+I6dZ5gF9eBCO35RzkX0xDxyS/nJTblZkW2LpJXI4QMlSK2UL
QPFW1Cj944OlqrwbfzqA6D4e/3l4vNcrelkFA/0y7XFBNy8aHBKntg0jpoCwhaoIAO7R2I7cEFNP
LwcHMxRxx7vjIQkt+xKIxmUO2u3q/OX6UV9CKoDetak+t8KQRvo89RI3tJILkpWubuJaEDh1qEi9
eCVJNMhxXxB7EFP1KaKDCA41rppz15Mg8GIShNTXmSCPX+2qBzdzUdFp6tAwBgJsWgxWhxaSuHOK
5QLLa52ddoxF6cv1kCEqt1Zs+oFDDUHSYCQNSI+eZdM5pNBJxqRHjOfrj31ptvhWhS2J/+lA/PGn
ygxmEHV9SmoTobVsUbXEd143WKFx5fU+Pk6sKOFAh/gToR+sZ8BFnNC5nUD94VvnUBpyTlJ7XFB2
1lPWM47vTA6kkKSx4sZDIGK7Y958nPoQRWcQzgtebqxbUC8jtmG75dKMr5GR2tgQGxvYJ3z7Jn5u
q1tZiKrnoRKdfiGdxv1MSW24bY/EPKUujxbi6jpsZXFvLWnOyLVPPVHz3cnKD5KM3TaxxG7qvs3U
fa7Noh6CxZ2xwsVKkwD2CK7N9m0QO6L1434WHWujPiFz5IWsQBsCQrp+7SYXk1wSh/D6eM2ot6px
mYfQdh69S+Ktxm7YXFYRXshV6edIr3SvLbQbPwjYknYaQS3tV6rU6yBdxZrEognbD8F3QU4cQHjS
nuZ+vncAvQHsEuB5iYploFEKi1lKx325wbNrubIW/Qe4b3fjLtFuS21gu9KEExqjWOg7PmU7d0yG
hwcn/SNDVcBvMHRnW2mwsKiV50QTJ3BE/0TeD+CvFOsKnDc5HQ+O1a6qlUo9sN8lUbMSm/f19/aH
B5PhkWmFrml7KZghejt1qQf7ccEaAIJbUD0ihmjJQ19FOF7MYJGiNsa93dVVioOdwkL3HuygUWZR
kIaoT1DJRRAnaA4Q7D02g0CAh++qqzAKksCG+seMLd90mTTx2/hqbvhMpvHHfbYD2OC/5tJu5PiJ
xcgSODYyuj2GrI0gnuCRZY/V0ZhzssGDGzdOYliiOHS7lVe+FDZrGX46n0TUDiInbhUZq0yE+3Xz
0Vsu4AqSCQZdwtYGffkal7Cto9z7KHLYJrCJsBjI3UQYt4QJ7AVfyflwiphFrtCbaYROlGl0ybu7
ZY755Dp/Y0GVMVkDHkeH47Xw8YGBOYEqSj9hp8qwBfBc20Jsm+zA71EYglkOad2KaKRmY9SuSOTq
dtZVIAk6/8rD123+E4xBiOHUVhlmrSIILsVPn3O6AnM4jcMu7ymo5ZpvFb0Afugs2EvDM9vlfDnX
ZUsknP/nXlus8TR1ncxpKz6bh9mWITz2r8/QFlMP4uUmY8via0n5ZAuGGClQBVUWyVv30c1zjqvH
jfX+XePJ11YsXKe87eeuf3o63OvmC0FWy3sS9b3MMGoIho/K2Zi0ayu6WlTtDUaDkwEC60xG1pna
Patg64yB6+zB6DIlO5ypDSX6I0Ks5YGSnAWPsPE2iS/dMGR1BIu1sNtj23H5bm6wu8OPC3zY/pHh
nqGcHP7X4KDwOAh+oBa2RFhh59VrY+flC0P8bXpgkzhhK02CS+rzGPhJt65jndo7+pwmFh4U6axX
TxIP77cC34EaaKfzqs32TIy9TSfMDQTbO6gAuJiMKrlbKJyl4zQz46C7jkh4+leW83LGsjfI8qgp
vydkelNqEtRV4KVzWs5F0IYN8pkfid2vVGrEI8IlQJij+iMj8jQp6O5gFwOGQHyTiy0lFikwS3Lz
SK6i8KU+FL81E50JXqJAb+BDbKOiUYr7TTF/yUZas1lEZ2gxzFiVGdjZYWNZKlIniTUrMpuaWWro
dFuyNbMEpGIRiK4B3UVBmPfOg9RPjgLXT7qVVUP/ZwUzUexRGpJOW/k7OB86Umm1arilKkVrGJ5F
YPhxzE4eZJ96ytrcBA4QUpiEas6PFsLmEsgSMrMV9V82i1+wiKjeXLLzhedxhcB02KA5PFIH89Cj
4BtybqjGbZjALv3ukZJdrIqKQObP5hIHPNz1cDuVkVtnl3C1hrc9iX0qzvaWVwmluLBR1BlFAAEj
8imnp66MuasmtN1TG5SgXaoOisKgYHiv0SuRbb1qoKC/bMh3zdTvSP93WvrHZ/uKxc3SujHT16UQ
fhbnpf79WUQMyi6WirSS3UotZ2TzdftnEkxFZtrKcswo9X9kggFJa7MLqsYsr8rUsvVk6SaEWqRI
H0X2yVbZev/vLIaj7ibJhetPoNK6cvHoAcAxidMQHzpM+FmbA9OTKKV50lk/Pa1sfFha8FaV+cQx
A/WXHbqgs/Ldx53ag7CBgsnbCQgauagPiBj3GKkhhAjezfEDKJTAu17kEGSbwkYd0ccGjH8wYqC9
zWKxTbHCIniriCU9uybDCh4VsAjSXJNJwJr5VkPuURk89q0nOut4yK4a+OJ1qBwRoGnVBRnwWmXk
tbAht6/kmnyFdX4s7Ymk8Q1OX4RcaSyo3rUtbwJgSSZ+Oj+nEYxuc+eXk5bluew2FlUOS8rNI2Fb
ZY8GR0z1P/AkI9P5W/jBaI4ehWo3uEKzcqTQYVORAoTZNpZjUw46+XpLQaf24LFC5L6DR0S7rONH
uXpjIKmxXuVhwz8TJX6oZTH2sEfENHItj1zQG+JT6oAq8PQVTxjYPcy5F9iX4q0DQRoC5XzaAfOZ
H1hkywkzZiJkfgu7OEmkFZSuyvvgTCnpfTVPloRpZcJ8oDeZJCx53soyMgFubhyih/J5RT6zOcUK
m3FmzF5ZihBXX9YV7JjQfg9LjNW3RSzDsLoVds80muLhEbhFBGNonPMFdMklLXuFNMzGxz8AHD5N
roPo0nRDM5ez9mxXAMcN8TwK19UZHhVIqRF7bYgwapOOyrDghobQUkvw2XlaPjs1fKQSLVsaAAiv
e+XWHdYqwaqqBu02a/nZfL7cKsbsrIzZkcesPjt4AGSIFbH9TcYaGiDiFmyaqsJHMXoqB9kD7vi4
gfFJrIg9yWLP3fDlTbwtPGd4VFqZygFhOXOi63MYiDfejM4CH/aH+WNmHTckAADf4bRjfKkNkoLf
5wZ+3HOiewRwKDvWuVMAeT3fjTw3fDUoscvETN3Zgbmq8Jb8BB2g+oR6Bmezri+hpA0jABvRdpYt
aLqAHImu1SkXiycV2cRLgIqAuLKqhIgbop8QrTK2LLBPSi+7/GgifozxIfBvZYWNghn/CKiqsXqR
HiAR1s7+vca/m0CQJrwI6TsOc6Np4HnBNVo4Lp4KYAd7hpE/9WBP09iz2S5MdujUgp4Yiv5n4K4p
JNDJNHLBot5igpEzJgsas76p6zvFU6GsfQn/SY2cjPS2STTgP9fXrkN+fdVuW+3Xv7WzfA7JelmM
gc0CFJblOo33Lhkz2T6n3KhNy9smfTDtzGeVF+pCLscMgBDky2F/NPkw+NQrCgelPxr2xz25YFF2
Dw/e9WrYsLxB2ftG/QtRmexnyXPtltFYairRcGqeMXgOY6ew29gWsec22ZWU5YvVuz4zW82S8tDM
T65IS2OcWpWve1bisPQYLeQygYrxr+Xk3LIv01C8mA5+ia55P1tatrJWhpJWZUHs3jQfVQOe1Qn5
N0Qts2a8Gde1Gs/rWhGApmBQvT3NeWSSm9bZWdJARKYhPuCQl1XB/Z1LqoyF5VRaYCk1fvSwZdQQ
qCwhJ8Fi7pSoZ37h6Gd+oyawq4b6mb888/lHaYwLZnMZ+a3/kSPAqoLyZZTGsbVIgQKZnyXlINFi
7+wzN12qLT6I+wl2ck/j7SBkpocVBciMcew9fLWCqcyRu5vgtaqT1eDkNEYnfLiGr2Agl2zaVsKp
4AeJdc9FodCtvHhkkaBMmz86JvaF5a/7uUDxgDBa4ZA9j33ks+s1KK/OguhUoy8Ro+q6qkeAKCp7
MDVlYdKn1yQE5i5Lh/zOHyKkeL7de91WWP17ZXm9l4AZKwSk9tqKcn2BFvqLaKKN6B5YKHv1/Vn+
kgg2CMCYfWfAv2Yo7XXvfkJyAiKK0wF5UiFoNukcMsSlHJ/4pauWSS/iBpdf29zMxP6FZCO2thT2
0RCT+KcHyLyOvOV3a7FBBpBvml4kkuq+wHFh14af5k3QrL25nyjs2nkS4r1zORPXeoc4+GWTCJtE
TO22TBYPeySqy7XcY34JRIBWmZSpSYQe5x3i66k7KTeEArFYFkK4k/FQIBszi4rrrXEaG/QmeVEm
wSist7haMfeZMVhZWki6nkBspo5gqhXqe9gj5UwfY4+PUDhOF+zMz7yOXLyA4A8D1lkrLwjxKY5A
r8u+icDv2e6UxcQp+P2EayQ3sGbrHtmr49fREWD0ITRLy303/uSL/byoVPnyioNio0GduJnhY/F/
voABfwqB4/wB2nwoYjjOsvJoe+LTBCiQNmmz7F7I8H/7/khzWqX1lBZ0zL45J/zb8lJPPwG/Cdm+
fSR/8K4q5e/Ne61brBKCNLLpURTA4hMX3wvdqmPWpnbVPRp6wWIy2N2Z/Ol+tSJH3YYpM3yr3lVh
J5F/Gd9Sl9jzJQUDn7CbXXV3NFSXLaX0Lb5S+V8Q4HFZvhfie2XP/cq+gKh+w0523tR9bFvafGer
Lehss28pFyy/+6TTjg1DZJj8DRJLyrKMolTlct55bXLK/sq//s/f6FSvN2oP06qT+dv81SdxY4aU
BtroE5gZpuWvVv8XVPIEubpEAAA=
EOF3

chmod +x /tmp/linux_userData.sh
/tmp/linux_userData.sh
