import { DataSource, DataSourceOptions } from 'typeorm';
require('dotenv').config();

const baseConfig: DataSourceOptions = {
  type: process.env.DATABASE_TYPE as any,
  host: process.env.DATABASE_HOST,
  port: parseInt(process.env.DATABASE_PORT),
  username: process.env.DATABASE_USERNAME,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_DB,
  synchronize: false,
  extra: {
    max: parseInt(process.env.TYPEORM_CONNECTION_LIMIT || '100'),
    maxQueryExecutionTime: parseInt(process.env.TYPEORM_QUERY_TIMEOUT || '60000'),
  },
  logging: ['error'],
};

export const ormConfig: DataSourceOptions = {
  ...baseConfig,
  entities: ['dist/**/entities/*.entity{.js,.ts}'],
};

const cliConfig: DataSourceOptions = {
  ...baseConfig,
  entities: ['src/**/entities/*.entity{.js,.ts}'],
  migrations: ['src/**/migrations/*{.js,.ts}'],
  logger: 'file',
  logging: true,
};

const cliDataSource = new DataSource(cliConfig);
export default cliDataSource;
