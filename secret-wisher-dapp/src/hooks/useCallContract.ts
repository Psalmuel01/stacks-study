import { useCallback } from 'react';
import { request } from '@stacks/connect';
import { type ClarityValue } from '@stacks/transactions';

interface CallContractParams {
    functionName: string;
    functionArgs?: ClarityValue[];
}

const contract = "ST2A2DJN1S6CPYDR5T00RBNNQKV6XZDKQDFJTYW1V.secret-wisher"

export function useCallContract() {
    const callContract = useCallback(async ({
        functionName,
        functionArgs,
    }: CallContractParams) => {
        try {
            console.log("functionName", functionName);
            console.log("functionArgs", functionArgs);
            const response = await request('stx_callContract', {
                contract,
                functionName,
                functionArgs,
                network: 'testnet',
            });

            console.log('Transaction ID:', response);
            return response;
        } catch (error) {
            console.error('Contract call failed:', error);
            throw error;
        }
    }, []);

    return { callContract };
}
