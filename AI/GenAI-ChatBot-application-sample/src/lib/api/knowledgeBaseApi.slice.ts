import { apiSlice, selfHandleErrors } from "./api.slice";
import { ApiRequest, KnowledgeBase } from "./api.types";

interface KnowledgeBaseApiParams extends ApiRequest {
    knowledgebaseId: string
}

const knowledgeBaseApiSlice = apiSlice.injectEndpoints({
    endpoints: builder => ({
        getKnowledgebases: builder.query<KnowledgeBase, KnowledgeBaseApiParams>({
            query: ({ knowledgebaseId }) => {
                return {
                    url: `knowledge-bases/${knowledgebaseId}/v1`
                }
            },
            onCacheEntryAdded: selfHandleErrors,
            providesTags: [{ type: 'knowledgeBase', id: 'LIST' }]
        }),
    })
});

export const {
    useGetKnowledgebasesQuery
} = knowledgeBaseApiSlice;