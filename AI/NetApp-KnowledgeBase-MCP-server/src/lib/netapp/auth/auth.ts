import got from 'got';
import {BLUEXP_URL} from "../../../utils/consts";

export async function generateToken(){
    return got
        .post(`${BLUEXP_URL}/auth/oauth/token`, {
            json: {
                audience: 'https://api.cloud.netapp.com',
                client_id: process.env.CLIENT_ID!,
                client_secret: process.env.CLIENT_SECRET!,
                grant_type: 'client_credentials'
            }
        })
        .json<{
            access_token: string;
            expires_in: number;
            token_type: string;
        }>();
}