import { useCallback } from 'react';
import { request } from '@stacks/connect';
import {
    fetchCallReadOnlyFunction,
    type ClarityValue,
} from '@stacks/transactions';
import { STACKS_MAINNET } from '@stacks/network';

interface CallContractParams {
    functionName: string;
    functionArgs?: ClarityValue[];
}

const contract = 'SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ.counter';
const contractAddress = 'SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ';
const contractName = 'counter';
const network = STACKS_MAINNET;

export function useContract() {
    const callContract = useCallback(
        async ({ functionName, functionArgs }: CallContractParams) => {
            try {
                console.log('functionName', functionName);
                console.log('functionArgs', functionArgs);
                const response = await request('stx_callContract', {
                    contract,
                    functionName,
                    functionArgs,
                    network: "testnet",
                });

                console.log('Transaction ID:', response);
                return response;
            } catch (error) {
                console.error('Contract call failed:', error);
                throw error;
            }
        },
        []
    );

    const readContract = useCallback(
        async (
            functionName: string,
            functionArgs: ClarityValue[] = [],
            senderAddress = 'SP13J1C3K69H3EDG2SVJ21SQ6GXD6A6F860HWK3ZJ'
        ) => {
            try {
                const options = {
                    contractAddress,
                    contractName,
                    functionName,
                    functionArgs,
                    network,
                    senderAddress,
                };

                const result = await fetchCallReadOnlyFunction(options);
                console.log('Contract call result:', result);
                return result;
            } catch (error) {
                console.error('Contract call failed:', error);
                throw error;
            }
        },
        []
    );

    return { callContract, readContract };
}