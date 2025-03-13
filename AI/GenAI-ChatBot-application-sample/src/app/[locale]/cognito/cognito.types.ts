export interface User {
    username: string,
    pool: {
        userPoolId: string,
        clientId: string
    },
    signInUserSession: {
        refreshToken: {
            token: string
        },
        accessToken: {
            jwtToken: string,
        },
        idToken: {
            payload: {
                email?: string
            }
        }
    }
}

export interface CognitoPayload {
    success: boolean,
    message: string,
    username: string,
    user: User
}