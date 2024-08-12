const prod = {
    endpointAfterRegistration: "/registerconfirm"
};

const dev = {
    endpointAfterRegistration: "/registerconfirm"
};

export const config = dev //process.env.NODE_ENV === "development" ? dev : prod;
