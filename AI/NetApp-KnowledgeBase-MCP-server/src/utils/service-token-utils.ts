import ms from 'ms';
import {generateToken} from "../lib/netapp/auth/auth";
interface serviceTokenDetails {
    accessToken: string;
    expiresIn: number;
}

let serviceToken:serviceTokenDetails|undefined = undefined;


function shouldRenew() {
    return !serviceToken || Date.now() > serviceToken.expiresIn - ms('1h');
}

export async function getToken(){
    if (shouldRenew()){
        const {access_token, token_type, expires_in:expiresIn} = await generateToken();
        serviceToken = {accessToken:`${token_type} ${access_token}`, expiresIn}
    }
    return serviceToken?.accessToken
}