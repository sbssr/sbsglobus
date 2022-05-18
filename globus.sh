#!/bin/bash

envname = '$HOME/tmpenv'

echo "Please enter a collection id:"
read collectionID

echo "Please enter a download file:"
read downloadFILE

python3 -m venv $HOME/$envname

source $HOME/$envname/bin/activate
pip install --upgrade pip
pip install setuptools-rust
pip install globus-sdk

cat << EOF > sbsclient.py
import globus_sdk
from globus_sdk import TransferClient, AccessTokenAuthorizer
import requests
import json
from collections import deque
import sys, getopt
from os import path

CLIENT_ID = "d560ddf9-f99a-432a-8e0d-4598135a4019"

def getSBSclient(ci):
    collectionID = ci
    client = globus_sdk.NativeAppAuthClient(CLIENT_ID)
    return client

def auth(client,collectionID):
    client = client
    ci = collectionID
    scope1=f"https://auth.globus.org/scopes/{ci}/https"
    requested_scopes=["openid","profile","email","urn:globus:auth:scope:transfer.api.globus.org:all", scope1]

    client.oauth2_start_flow(requested_scopes=requested_scopes)

    authorize_url = client.oauth2_get_authorize_url()
    print(f"Please go to this URL and login:\n\n{authorize_url}\n")

    auth_code = input("Please enter the code you get after login here: ").strip()
    token_response = client.oauth2_exchange_code_for_tokens(auth_code)

    globus_auth_data = token_response.by_resource_server["auth.globus.org"]
    globus_transfer_data = token_response.by_resource_server["transfer.api.globus.org"]
    globus_collection_data = token_response.by_resource_server[ci]

    AUTH_TOKEN = globus_collection_data.get('access_token')
    TRANSFER_TOKEN = globus_transfer_data.get('access_token')
    return (AUTH_TOKEN,TRANSFER_TOKEN)

def getTransferClient(tt):
    TRANSFER_TOKEN = tt
    transfer_client = TransferClient(authorizer=AccessTokenAuthorizer(TRANSFER_TOKEN))
    return transfer_client

def getDownloadURL(tc,ci):
    transfer_client = tc
    collectionID = ci
    endpoint = transfer_client.get_endpoint(collectionID)
    https_server = endpoint['https_server']
    return https_server

def getDownloadCommand(du,df,at):
    downloadURL = du
    downloadFILE = df
    AUTH_TOKEN = at
    dl = "curl -H \"Authorization: Bearer %s\" %s --output %s" %(AUTH_TOKEN, path.join(downloadURL, downloadFILE), downloadFILE)
    return dl

def main(argv):
    collectionID = ''
    downloadFILE = ''
    try:
        opts, args = getopt.getopt(argv,"hc:d:",["collectionID=","downloadFILE="])
    except getopt.GetoptError:
        print ('sbs_globus_client.py -c <collectionID> -d <downloadFILE>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print ('sbs_globus_client.py -c <collectionID> -d <downloadFILE>')
            sys.exit()
        elif opt in ("-c", "--collectionID"):
            collectionID = arg
        elif opt in ("-d", "--downloadFILE"):
            downloadFILE = arg           
    
    if collectionID == '' or downloadFILE == '':
        print ('sbs_globus_client.py -c <collectionID> -d <downloadFILE>')
        sys.exit()

    client = getSBSclient(collectionID)
    (AUTH_TOKEN,TRANSFER_TOKEN) = auth(client,collectionID)
    transfer_client = getTransferClient(TRANSFER_TOKEN)
    downloadURL = getDownloadURL(transfer_client,collectionID)
    downloadCommand = getDownloadCommand(downloadURL,downloadFILE,AUTH_TOKEN)
    print("\nPlease use the command below to download your file:\n" + downloadCommand)


if __name__ == "__main__":
    main(sys.argv[1:])

EOF

chmod 755 sbsclient.py
python3 sbsclient.py -c $collectionID -d $downloadFILE
deactivate
rm -fR $HOME/$envname