import { ReactElement, useMemo, useState } from 'react';
import { Table, Flex, Radio, Typography } from 'antd';
import { Buffer } from 'buffer';
import { useUpdateCall } from '@ic-reactor/react';
// import {} from '../declarations/backend/backend.did';
import {
    backend,
    useQueryCall,
    Options,
    GetTxsResponse,
    Block,
} from '../backend-actor';
import { render } from '@testing-library/react';
import type { InputNumberProps } from 'antd';
import {
    Tag,
    Cascader,
    Input,
    Select,
    Space,
    DatePicker,
    Card,
    Button,
    InputNumber,
    Pagination,
    Switch,
    Alert,
    Collapse,
} from 'antd';
import { useQuery } from 'react-query';
import type { SelectProps } from 'antd';
import { queryClient } from '../utils/react-query-client';
import { useSearch, useLocation } from 'wouter';
import dayjs from 'dayjs';

const { RangePicker } = DatePicker;
type TagRender = SelectProps['tagRender'];

const { Paragraph, Text } = Typography;

const number_with_comma = (n: string) => {
    let [whole, decimal] = n.split('.');
    let whole_with_comma = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return decimal ? whole_with_comma + '.' + decimal : whole_with_comma;
};

const render_address = (from: Uint8Array | number[]) => {
    return from ? (
        <Text copyable ellipsis>
            {Buffer.from(new Uint8Array(from)).toString('hex')}
        </Text>
    ) : (
        <span>----</span>
    );
};

const format_with_icp_decimals = (amt: bigint) => Number(amt) / 10 ** 8;

const render_icp = (amt: bigint) =>
    number_with_comma(
        (amt ? format_with_icp_decimals(BigInt(amt)) : 0).toFixed(8),
    ) + ' ICP';

const columns = [
    {
        title: 'Tx Index',
        dataIndex: 'tx_index',
        key: 'tx_index',
        render: (tx_index: bigint) => tx_index.toString(),
    },
    { title: 'Block Type', dataIndex: 'btype', key: 'btype' },
    {
        title: 'Fee',
        dataIndex: 'fee',
        key: 'fee',
        render: render_icp,
    },
    {
        title: 'Amount',
        dataIndex: 'amt',
        key: 'amt',
        render: render_icp,
    },
    {
        title: 'Time',
        dataIndex: 'ts',
        key: 'ts',
        render: (ts: bigint) =>
            dayjs(Number(ts / (1000n * 1000n))).format(
                'YYYY-MM-DD, hh:mm:ss A',
            ),
    },
    {
        title: 'Sender',
        dataIndex: 'from',
        key: 'from',
        render: render_address,
    },
    {
        title: 'Recipient',
        dataIndex: 'to',
        key: 'to',
        render: render_address,
    },
    {
        title: 'Spender',
        dataIndex: 'spender',
        key: 'spender',
        render: render_address,
    },
];

type DisplayedTx = {
    ts: bigint;
    to?: Uint8Array;
    amt?: bigint;
    from?: Uint8Array;
    memo?: Uint8Array;
    expected_allowance?: bigint;
    expires_at?: bigint;
    spender?: Uint8Array;
    fee?: bigint;
    btype: string;
    phash?: Blob;
    tx_index: bigint;
};

export type BlockFnKeys =
    | 'get_txs_by_index'
    | 'get_txs_by_amt'
    | 'get_txs_by_ts'
    | 'get_txs_by_fee';

export type IOptions = {
    pagination: {
        limit: number;
        offset: number;
    };
    sort: { Ascending: null } | { Descending: null };
};

export interface TxsTableProps<T> {
    title: ReactElement<any, any>;
    fn_name: BlockFnKeys;
    start?: T;
    end?: T;
    options: IOptions;
}

export const TxsTable = <T,>({
    title,
    fn_name,
    start,
    end,
    options,
}: TxsTableProps<T>) => {
    const [performance_state, set_performance_state] = useState({
        instructions: 0,
        time: 0,
    });

    const [pagination, set_pagination] = useState(options.pagination);

    const [total, set_total] = useState<number>(0);
    const [instructions, set_instructions] = useState<number>(0);

    const {
        data: blocks,
        refetch,
        isFetching: is_table_loading,
        isError: is_table_request_failed,
        error: table_request_error,
    } = useQuery(
        [fn_name, start, end, options, pagination],
        async () => {
            let performance_start = performance.now();

            const res = (await backend[fn_name](
                start ? [BigInt(start! as number)] : [],
                end ? [BigInt(end! as number)] : [],
                {
                    sort: options.sort,
                    pagination: {
                        limit: BigInt(pagination.limit),
                        offset: BigInt(pagination.offset),
                    },
                },
            )) as GetTxsResponse;

            console.log({ res });

            set_total(Number(res.total));
            set_instructions(Number(res.instructions));

            const displayed_txs: [DisplayedTx] = res.blocks.map((block) => ({
                amt: block.tx.amt[0],
                to: block.tx.to[0],
                from: block.tx.from[0],
                memo: block.tx.memo[0],
                expected_allowance: block.tx.expected_allowance[0],
                expires_at: block.tx.expires_at[0],
                spender: block.tx.spender[0],
                fee: block.fee[0],
                ts: block.ts,
                btype: block.btype,
                phash: block.phash[0],
                tx_index: block.tx_index,
            })) as any as [DisplayedTx];

            console.log({ displayed_txs });

            let performance_end = performance.now();

            set_performance_state({
                instructions: Number(res.instructions),
                time: performance_end - performance_start,
            });

            return displayed_txs;
        },
        {
            cacheTime: 0,
        },
    );

    let ICP_LEDGER_DECIMALS = 8;

    const number_formatter = Intl.NumberFormat('en', { notation: 'compact' });

    return (
        <Card size={'default'}>
            <Space direction="vertical" style={{ width: '100%' }}>
                {is_table_request_failed ? (
                    <Alert
                        message="Error"
                        description={
                            (table_request_error as any)?.message as string
                        }
                        type="error"
                        showIcon
                    />
                ) : null}
                <Table
                    title={() => (
                        <Flex justify="space-between" align="end" dir="column">
                            {title}
                            <Typography.Title
                                level={3}
                                style={{ margin: 0 }}
                            ></Typography.Title>
                            <span>
                                <Typography.Text>
                                    Query Performance:{' '}
                                </Typography.Text>
                                <Typography.Text strong>
                                    {number_formatter.format(instructions)}{' '}
                                    Instructions
                                </Typography.Text>
                                {' | '}
                                <Typography.Text strong>
                                    {performance_state.time / 1000 >= 60
                                        ? (
                                              performance_state.time /
                                              1000 /
                                              60
                                          ).toFixed(0) +
                                          ' min' +
                                          ' ' +
                                          (
                                              (performance_state.time %
                                                  60_000) /
                                              1000
                                          ).toFixed(0) +
                                          ' s'
                                        : (
                                              (performance_state.time %
                                                  60_000) /
                                              1000
                                          ).toFixed(2) + ' s'}
                                </Typography.Text>
                            </span>
                            <span>
                                <Typography.Text>
                                    Total Transactions:{' '}
                                </Typography.Text>
                                <Typography.Text strong>
                                    {number_formatter.format(Number(total))}
                                </Typography.Text>
                            </span>
                        </Flex>
                    )}
                    size={'small'}
                    dataSource={is_table_request_failed ? [] : blocks}
                    columns={columns}
                    loading={is_table_loading}
                    pagination={false}
                />
                <Pagination
                    showQuickJumper
                    current={pagination.offset / pagination.limit + 1}
                    total={total}
                    pageSize={Number(pagination.limit)}
                    onChange={(page: number, page_size: number) => {
                        set_pagination((prev) => {
                            return {
                                limit: Number(page_size),
                                offset: Number(page_size * (page - 1)),
                            };
                        });
                    }}
                />
            </Space>
        </Card>
    );
};
