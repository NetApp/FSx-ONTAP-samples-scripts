import { BaseQueryFn, createApi, FetchArgs, fetchBaseQuery, FetchBaseQueryError } from '@reduxjs/toolkit/query/react';
import { AiChatState, Auth } from '../store.types';
import { ApiRequest, ApiResponse, PaginationApiResponse } from './api.types';
import { addSelfeHandleErrorRequestId } from '../slices/errorHandeling.slice';

export const pollingInterval = 30000;
export const pollingIntervalWizard = 600000;

export const apiMockResponseInitial: ApiResponse<any> = {
  isError: false,
  isFetching: true,
  isLoading: true,
  isSuccess: false,
}

export const paginationApiMockResponseInitial: PaginationApiResponse<any> = {
  isError: false,
  isFetching: true,
  isLoading: true,
  isSuccess: false,
}

export const BASE_URL = 'api.workloads.netapp.com';

export const selfHandleErrors = (args: ApiRequest, api: any) => {
  if (args.isSelfHandleErrors) {
    const { dispatch, requestId } = api;
    dispatch(addSelfeHandleErrorRequestId(requestId));
  }
}

const baseQuery = fetchBaseQuery({
  baseUrl: `https://${BASE_URL}/wlmai`,
  prepareHeaders: (headers, { getState }) => {
    const { accessToken } = (getState() as AiChatState).auth;

    if (accessToken) {
      const bearer = accessToken.includes('Bearer') ? '' : 'Bearer';
      headers.set('authorization', `${bearer} ${accessToken}`)
    }

    return headers
  }
})

const baseQueryWithReauth: BaseQueryFn<
  string | FetchArgs,
  unknown,
  FetchBaseQueryError
> = async (args, api, extraOptions) => {
  let result = await baseQuery(args, api, extraOptions)
  if (result.error) {
    // refresh Result
    // const refreshResult = await baseQuery('/refreshToken', api, extraOptions)
  }

  return result
}

// Define a service using a base URL and expected endpoints
export const apiSlice = createApi({
  reducerPath: 'api',
  baseQuery: baseQueryWithReauth,
  tagTypes: [
    'volumes',
    'fileSystems',
    'dataSources',
    'directories',
    'history',
    'awsCredentials',
    'awsRegions',
    'awsVpcs',
    'awsSubnets',
    'fsxs',
    'svms',
    'keyPairs',
    'deploy',
    'deployment',
    'knowledgeBase',
    'shares',
    'models'
  ],
  endpoints: (builder) => ({
  })
})

export const skip = (state: AiChatState, condition: boolean = false) => {
  const { auth = {} } = state;
  const { isSuccess = false, accessToken = '' } = (auth || {}) as Auth;
  return !isSuccess || !accessToken || condition;
}