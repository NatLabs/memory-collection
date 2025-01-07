import { useMemo, useState } from 'react';
import { Table, Flex, Radio, Typography } from 'antd';
import { Buffer } from 'buffer';
import { useUpdateCall } from '@ic-reactor/react';
import { Block } from '../declarations/backend/backend.did';
import { backend, useQueryCall, Options } from '../backend-actor';
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
import { TxsTable, IOptions } from '../components/TxsTable';
import { parse } from 'path';

const { RangePicker } = DatePicker;

const { Paragraph, Text } = Typography;

export const MemoryBTree = () => {
    const search_string = useSearch();
    const {
        data: stats,
        refetch: refetch_get_stats,
        isFetching: is_stats_loading,
        isError: is_stats_request_failed,
        error: stats_request_error,
    } = useQuery(
        ['get_stats'],
        async () => {
            const stats = await backend.get_stats();
            console.log({ stats });
            return stats;
        },
        {
            cacheTime: 0,
        },
    );
    const number_formatter = Intl.NumberFormat('en', { notation: 'compact' });

    const format_bytes = (bytes: number | bigint) => {
        let formatted = number_formatter
            .format(bytes)
            .replace('B', 'G') // -> replace Billion with Giga
            .replace('T', 'P'); // -> replace Trillion with Peta

        return formatted + 'B';
    };

    let heap_size = format_bytes(stats?.heap_size || 0);
    let memory_size = format_bytes(stats?.memory_size || 0);
    let stable_memory_size = format_bytes(stats?.stable_memory_size || 0);
    let total_allocation = format_bytes(stats?.total_allocation || 0);
    let max_live_size = format_bytes(stats?.max_live_size || 0);
    let logical_stable_memory_size = format_bytes(
        stats?.logical_stable_memory_size || 0,
    );

    let total_records = number_formatter.format(stats?.num_entries || 0);

    type Parameters = {
        min: number | null;
        max: number | null;
        options: IOptions;
    };

    const [tx_index_paramters, set_tx_index_parameters] = useState<Parameters>({
        min: null,
        max: null,
        options: {
            sort: { Ascending: null },
            pagination: { limit: 10, offset: 0 },
        },
    });

    const [ts_parameters, set_ts_parameters] = useState<Parameters>({
        min: null,
        max: null,
        options: {
            sort: { Ascending: null },
            pagination: { limit: 10, offset: 0 },
        },
    });
    const [amount_parameters, set_amount_parameters] = useState<Parameters>({
        min: null,
        max: null,
        options: {
            sort: { Ascending: null },
            pagination: { limit: 10, offset: 0 },
        },
    });
    const [fee_parameters, set_fee_parameters] = useState<Parameters>({
        min: null,
        max: null,
        options: {
            sort: { Ascending: null },
            pagination: { limit: 10, offset: 0 },
        },
    });

    const handle_sort_change = (
        setter: (fn: (prev: Parameters) => Parameters) => void,
    ): ((e: any) => void) => {
        return function (e) {
            let value = e.target.value;
            console.log({ value });

            setter(
                (prev: Parameters): Parameters => ({
                    ...prev,
                    options: {
                        ...prev.options,
                        sort:
                            value === 'Ascending'
                                ? { Ascending: null }
                                : { Descending: null },
                    },
                }),
            );
        };
    };

    console.log({ amount_parameters });

    const parse_num = (t: string) => {
        return t === '' ? null : Number(t.replaceAll(',', ''));
    };

    function opt<T>(t: T | null, fn: (n: T) => T): T | null {
        return t === null ? null : fn(t);
    }

    return (
        <Space size="large" direction="vertical">
            <Typography.Title level={2}>
                MemoryBTree test - Storing ICP transaction
            </Typography.Title>

            <Flex justify="space-between">
                <Typography.Title level={5} style={{ margin: 0 }}>
                    Canister Stats
                </Typography.Title>

                <Flex wrap={'wrap'} gap={15}>
                    <Typography.Text>Heap Size: {heap_size} </Typography.Text>
                    <Typography.Text>
                        Stable Memory: {logical_stable_memory_size}{' '}
                    </Typography.Text>
                    <Typography.Text>
                        Total Records: {total_records}
                    </Typography.Text>
                </Flex>
            </Flex>

            <TxsTable
                title={
                    <Space direction="vertical">
                        <Typography.Title level={3} style={{ margin: 0 }}>
                            Transactions sorted by Index
                        </Typography.Title>
                        <Space>
                            <Space direction="vertical">
                                <Text>Tx Index</Text>
                                <Flex gap={10}>
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Min"
                                        placeholder="Enter Min Tx Index"
                                        onChange={(e) => {
                                            let min = parse_num(e.target.value);

                                            set_tx_index_parameters((prev) => ({
                                                ...prev,
                                                min,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));
                                        }}
                                    />
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Max"
                                        placeholder="Enter Max Tx Index"
                                        onChange={(e) => {
                                            let max = parse_num(e.target.value);

                                            set_tx_index_parameters((prev) => ({
                                                ...prev,
                                                max,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));
                                        }}
                                    />
                                </Flex>
                            </Space>
                            <Space direction="vertical">
                                <Typography.Text>Sort</Typography.Text>
                                <Radio.Group
                                    defaultValue="Ascending"
                                    onChange={handle_sort_change(
                                        set_tx_index_parameters,
                                    )}
                                >
                                    <Radio value="Ascending">Ascending</Radio>
                                    <Radio value="Descending">Descending</Radio>
                                </Radio.Group>
                            </Space>
                        </Space>
                    </Space>
                }
                fn_name={'get_txs_by_index'}
                start={tx_index_paramters.min}
                end={tx_index_paramters.max}
                options={tx_index_paramters.options}
            />
            <TxsTable
                title={
                    <Space direction="vertical">
                        <Typography.Title level={3} style={{ margin: 0 }}>
                            Transactions sorted by Amount
                        </Typography.Title>
                        <Space>
                            <Space direction="vertical">
                                <Text>Amount</Text>
                                <Flex gap={10}>
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Min"
                                        placeholder="Enter Min Amount"
                                        onChange={(e) => {
                                            console.log({
                                                amount_min: e.target.value,
                                            });
                                            let min = opt(
                                                parse_num(e.target.value),
                                                (n) => (n * 10 ** 8) | 0,
                                            );

                                            set_amount_parameters((prev) => ({
                                                ...prev,
                                                min,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));
                                            console.log({ amount_parameters });
                                        }}
                                    />
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Max"
                                        placeholder="Enter Max Amount"
                                        onChange={(e) => {
                                            console.log({
                                                amount_max: e.target.value,
                                            });
                                            let max = opt(
                                                parse_num(e.target.value),
                                                (n) => (n * 10 ** 8) | 0,
                                            );

                                            set_amount_parameters((prev) => ({
                                                ...prev,
                                                max,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));

                                            console.log({ amount_parameters });
                                        }}
                                    />
                                </Flex>
                            </Space>
                            <Space direction="vertical">
                                <Typography.Text>Sort</Typography.Text>
                                <Radio.Group
                                    defaultValue="Ascending"
                                    onChange={handle_sort_change(
                                        set_amount_parameters,
                                    )}
                                >
                                    <Radio value="Ascending">Ascending</Radio>
                                    <Radio value="Descending">Descending</Radio>
                                </Radio.Group>
                            </Space>
                        </Space>
                    </Space>
                }
                fn_name={'get_txs_by_amt'}
                start={amount_parameters.min}
                end={amount_parameters.max}
                options={amount_parameters.options}
            />
            <TxsTable
                title={
                    <Space direction="vertical">
                        <Typography.Title level={3} style={{ margin: 0 }}>
                            Transactions sorted by Timestamp
                        </Typography.Title>
                        <Space>
                            <Space direction="vertical">
                                <Typography.Text>Date/Time</Typography.Text>
                                <RangePicker
                                    showTime
                                    onChange={(dates: any) => {
                                        console.log({ dates });

                                        if (dates === null) {
                                            return set_ts_parameters((prev) => {
                                                prev.min = null;
                                                prev.max = null;
                                                return prev;
                                            });
                                        }

                                        console.log([
                                            dates[0].valueOf(),
                                            dates[1].valueOf(),
                                        ]);

                                        const min_ts =
                                            Number(dates[0].valueOf()) *
                                            1000 ** 2;
                                        const max_ts =
                                            Number(dates[1].valueOf()) *
                                            1000 ** 2;

                                        console.log({ min_ts, max_ts });

                                        set_ts_parameters((prev) => {
                                            return {
                                                ...prev,
                                                min: min_ts,
                                                max: max_ts,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            };
                                        });

                                        console.log({ ts_parameters });
                                    }}
                                />
                            </Space>
                            <Space direction="vertical">
                                <Typography.Text>Sort</Typography.Text>
                                <Radio.Group
                                    defaultValue="Ascending"
                                    onChange={handle_sort_change(
                                        set_ts_parameters,
                                    )}
                                >
                                    <Radio value="Ascending">Ascending</Radio>
                                    <Radio value="Descending">Descending</Radio>
                                </Radio.Group>
                            </Space>
                        </Space>
                    </Space>
                }
                fn_name={'get_txs_by_ts'}
                start={ts_parameters.min}
                end={ts_parameters.max}
                options={ts_parameters.options}
            />
            <TxsTable
                title={
                    <Space direction="vertical">
                        <Typography.Title level={3} style={{ margin: 0 }}>
                            Transactions sorted by fee
                        </Typography.Title>
                        <Space>
                            <Space direction="vertical">
                                <Text>Fee</Text>
                                <Flex gap={10}>
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Min"
                                        placeholder="Enter Min Fee"
                                        onChange={(e) => {
                                            console.log({
                                                min: e.target.value,
                                            });
                                            console.log({
                                                min2: parse_num(e.target.value),
                                            });
                                            let min = opt(
                                                parse_num(e.target.value),
                                                (n) => (n * 10 ** 8) | 0,
                                            );

                                            console.log({ min });
                                            set_fee_parameters((prev) => ({
                                                ...prev,
                                                min,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));
                                        }}
                                    />
                                    <Input
                                        size={'small'}
                                        allowClear={true}
                                        addonBefore="Max"
                                        placeholder="Enter Max Fee"
                                        onChange={(e) => {
                                            console.log({
                                                max: e.target.value,
                                            });
                                            console.log({
                                                max2: parse_num(e.target.value),
                                            });
                                            let max = opt(
                                                parse_num(e.target.value),
                                                (n) => (n * 10 ** 8) | 0,
                                            );

                                            console.log({ max });
                                            set_fee_parameters((prev) => ({
                                                ...prev,
                                                max,
                                                pagination: {
                                                    ...prev.options.pagination,
                                                    offset: 0,
                                                },
                                            }));
                                        }}
                                    />
                                </Flex>
                            </Space>
                            <Space direction="vertical">
                                <Typography.Text>Sort</Typography.Text>
                                <Radio.Group
                                    defaultValue="Ascending"
                                    onChange={handle_sort_change(
                                        set_fee_parameters,
                                    )}
                                >
                                    <Radio value="Ascending">Ascending</Radio>
                                    <Radio value="Descending">Descending</Radio>
                                </Radio.Group>
                            </Space>
                        </Space>
                    </Space>
                }
                fn_name={'get_txs_by_fee'}
                start={fee_parameters.min}
                end={fee_parameters.max}
                options={fee_parameters.options}
            />
        </Space>
    );
};
