/*-------------------------------------------------------------------------
 *
 * mongo_wrapper_meta.c
 * 		Wrapper functions for remote MongoDB servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
 * Portions Copyright (c) 2012–2014 Citus Data, Inc.
 *
 * IDENTIFICATION
 * 		mongo_wrapper_meta.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <mongoc.h>
#include "mongo_wrapper.h"

/*
 * MongoConnect
 *		Connect to MongoDB server using Host/ip and Port number.
 */
MONGO_CONN *
MongoConnect(MongoFdwOptions *opt)
{
	MONGO_CONN *client;
	char	   *uri;

	if (opt->svr_username && opt->svr_password)
	{
		if (opt->authenticationDatabase)
		{
			if (opt->replicaSet)
			{
				if (opt->readPreference)
					uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?readPreference=%s&ssl=%s&authSource=%s&replicaSet=%s",
											 opt->svr_username,
											 opt->svr_password,
											 opt->svr_address, opt->svr_port,
											 opt->svr_database,
											 opt->readPreference,
											 opt->ssl ? "true" : "false",
											 opt->authenticationDatabase,
											 opt->replicaSet);
				else
					uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?ssl=%s&authSource=%s&replicaSet=%s",
											 opt->svr_username,
											 opt->svr_password,
											 opt->svr_address, opt->svr_port,
											 opt->svr_database,
											 opt->ssl ? "true" : "false",
											 opt->authenticationDatabase,
											 opt->replicaSet);
			}
			else if (opt->readPreference)
				uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?readPreference=%s&ssl=%s&authSource=%s",
										 opt->svr_username, opt->svr_password,
										 opt->svr_address, opt->svr_port,
										 opt->svr_database,
										 opt->readPreference,
										 opt->ssl ? "true" : "false",
										 opt->authenticationDatabase);
			else
				uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?ssl=%s&authSource=%s",
										 opt->svr_username, opt->svr_password,
										 opt->svr_address, opt->svr_port,
										 opt->svr_database,
										 opt->ssl ? "true" : "false",
										 opt->authenticationDatabase);
		}
		else if (opt->replicaSet)
		{
			if (opt->readPreference)
				uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?readPreference=%s&ssl=%s&replicaSet=%s",
										 opt->svr_username, opt->svr_password,
										 opt->svr_address, opt->svr_port,
										 opt->svr_database,
										 opt->readPreference,
										 opt->ssl ? "true" : "false",
										 opt->replicaSet);
			else
				uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?ssl=%s&replicaSet=%s",
										 opt->svr_username, opt->svr_password,
										 opt->svr_address, opt->svr_port,
										 opt->svr_database,
										 opt->ssl ? "true" : "false",
										 opt->replicaSet);
		}
		else if (opt->readPreference)
			uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?readPreference=%s&ssl=%s",
									 opt->svr_username, opt->svr_password,
									 opt->svr_address, opt->svr_port,
									 opt->svr_database, opt->readPreference,
									 opt->ssl ? "true" : "false");
		else
			uri = bson_strdup_printf("mongodb://%s:%s@%s:%hu/%s?ssl=%s",
									 opt->svr_username, opt->svr_password,
									 opt->svr_address,
									 opt->svr_port, opt->svr_database,
									 opt->ssl ? "true" : "false");
	}
	else if (opt->replicaSet)
	{
		if (opt->readPreference)
			uri = bson_strdup_printf("mongodb://%s:%hu/%s?readPreference=%s&ssl=%s&replicaSet=%s",
									 opt->svr_address, opt->svr_port,
									 opt->svr_database, opt->readPreference,
									 opt->ssl ? "true" : "false",
									 opt->replicaSet);
		else
			uri = bson_strdup_printf("mongodb://%s:%hu/%s?ssl=%s&replicaSet=%s",
									 opt->svr_address, opt->svr_port,
									 opt->svr_database,
									 opt->ssl ? "true" : "false",
									 opt->replicaSet);
	}
	else if (opt->readPreference)
		uri = bson_strdup_printf("mongodb://%s:%hu/%s?readPreference=%s&ssl=%s",
								 opt->svr_address, opt->svr_port,
								 opt->svr_database, opt->readPreference,
								 opt->ssl ? "true" : "false");
	else
		uri = bson_strdup_printf("mongodb://%s:%hu/%s?ssl=%s",
								 opt->svr_address, opt->svr_port,
								 opt->svr_database,
								 opt->ssl ? "true" : "false");


	client = mongoc_client_new(uri);

	if (opt->ssl)
	{
		mongoc_ssl_opt_t *ssl_opts = (mongoc_ssl_opt_t *) malloc(sizeof(mongoc_ssl_opt_t));

		ssl_opts->pem_file = opt->pem_file;
		ssl_opts->pem_pwd = opt->pem_pwd;
		ssl_opts->ca_file = opt->ca_file;
		ssl_opts->ca_dir = opt->ca_dir;
		ssl_opts->crl_file = opt->crl_file;
		ssl_opts->weak_cert_validation = opt->weak_cert_validation;
		mongoc_client_set_ssl_opts(client, ssl_opts);
		free(ssl_opts);
	}

	bson_free(uri);

	if (client == NULL)
		ereport(ERROR,
				(errmsg("could not connect to %s:%d", opt->svr_address,
						opt->svr_port),
				 errhint("Mongo driver connection error.")));

	return client;
}

/*
 * MongoDisconnect
 *		Disconnect from MongoDB server.
 */
void
MongoDisconnect(MONGO_CONN *conn)
{
	if (conn)
		mongoc_client_destroy(conn);
}

/*
 * MongoInsert
 *		Insert a document 'b' into MongoDB.
 */
bool
MongoInsert(MONGO_CONN *conn, char *database, char *collection, BSON *b)
{
	mongoc_collection_t *c;
	bson_error_t error;
	bool		r = false;

	c = mongoc_client_get_collection(conn, database, collection);

	r = mongoc_collection_insert(c, MONGOC_INSERT_NONE, b, NULL, &error);
	mongoc_collection_destroy(c);
	if (!r)
		ereport(ERROR,
				(errmsg("failed to insert row"),
				 errhint("Mongo error: \"%s\"", error.message)));

	return true;
}

/*
 * MongoUpdate
 *		Update a document 'b' into MongoDB.
 */
bool
MongoUpdate(MONGO_CONN *conn, char *database, char *collection, BSON *b,
			BSON *op)
{
	mongoc_collection_t *c;
	bson_error_t error;
	bool		r = false;

	c = mongoc_client_get_collection(conn, database, collection);

	r = mongoc_collection_update(c, MONGOC_UPDATE_NONE, b, op, NULL, &error);
	mongoc_collection_destroy(c);
	if (!r)
		ereport(ERROR,
				(errmsg("failed to update row"),
				 errhint("Mongo error: \"%s\"", error.message)));

	return true;
}

/*
 * MongoDelete
 *		Delete MongoDB's document.
 */
bool
MongoDelete(MONGO_CONN *conn, char *database, char *collection, BSON *b)
{
	mongoc_collection_t *c;
	bson_error_t error;
	bool		r = false;

	c = mongoc_client_get_collection(conn, database, collection);

	r = mongoc_collection_remove(c, MONGOC_DELETE_SINGLE_REMOVE, b, NULL,
								 &error);
	mongoc_collection_destroy(c);
	if (!r)
		ereport(ERROR,
				(errmsg("failed to delete row"),
				 errhint("Mongo error: \"%s\"", error.message)));

	return true;
}

/*
 * MongoCursorCreate
 *		Performs a query against the configured MongoDB server and return
 *		cursor which can be destroyed by calling mongoc_cursor_current.
 */
MONGO_CURSOR *
MongoCursorCreate(MONGO_CONN *conn, char *database, char *collection, BSON *q)
{
	mongoc_collection_t *c;
	MONGO_CURSOR *cur;
	bson_error_t error;

	c = mongoc_client_get_collection(conn, database, collection);
	cur = mongoc_collection_aggregate(c, MONGOC_QUERY_NONE, q, NULL, NULL);
	mongoc_cursor_error(cur, &error);
	if (!cur)
		ereport(ERROR,
				(errmsg("failed to create cursor"),
				 errhint("Mongo error: \"%s\"", error.message)));

	mongoc_collection_destroy(c);

	return cur;
}

/*
 * MongoCursorDestroy
 *		Destroy cursor created by calling MongoCursorCreate function.
 */
void
MongoCursorDestroy(MONGO_CURSOR *c)
{
	mongoc_cursor_destroy(c);
}


/*
 * MongoCursorNext
 *		Get the current document from cursor.
 */
const BSON *
MongoCursorBson(MONGO_CURSOR *c)
{
	return mongoc_cursor_current(c);
}

/*
 * MongoCursorNext
 *		Get the next document from the cursor.
 */
bool
MongoCursorNext(MONGO_CURSOR *c, BSON *b)
{
	return mongoc_cursor_next(c, (const BSON **) &b);
}

/*
 * BsonCreate
 *		Allocates a new bson_t structure, and also initialize the bson object.
 *
 * After that point objects can be appended to that bson object and can be
 * iterated. A newly allocated bson_t that should be freed with bson_destroy().
 */
BSON *
BsonCreate(void)
{
	BSON	   *doc;

	doc = bson_new();
	bson_init(doc);

	return doc;
}

/*
 * BsonDestroy
 *		Destroy Bson object created by BsonCreate function.
 */
void
BsonDestroy(BSON *b)
{
	bson_destroy(b);
}

/*
 * BsonIterInit
 *		Initialize the bson Iterator.
 */
bool
BsonIterInit(BSON_ITERATOR *it, BSON *b)
{
	return bson_iter_init(it, b);
}

bool
BsonIterSubObject(BSON_ITERATOR *it, BSON *b)
{
	const uint8_t *buffer;
	uint32_t	len;

	bson_iter_document(it, &len, &buffer);
	bson_init_static(b, buffer, len);

	return true;
}

int32_t
BsonIterInt32(BSON_ITERATOR *it)
{
	return bson_iter_int32(it);
}

int64_t
BsonIterInt64(BSON_ITERATOR *it)
{
	return bson_iter_int64(it);
}

double
BsonIterDouble(BSON_ITERATOR *it)
{
	return bson_iter_double(it);
}

bool
BsonIterBool(BSON_ITERATOR *it)
{
	return bson_iter_bool(it);
}

const char *
BsonIterString(BSON_ITERATOR *it)
{
	uint32_t	len = 0;

	return bson_iter_utf8(it, &len);
}

const char *
BsonIterBinData(BSON_ITERATOR *it, uint32_t *len)
{
	const uint8_t *binary = NULL;
	bson_subtype_t subtype = BSON_SUBTYPE_BINARY;

	bson_iter_binary(it, &subtype, len, &binary);

	return (char *) binary;
}

const bson_oid_t *
BsonIterOid(BSON_ITERATOR *it)
{
	return bson_iter_oid(it);
}

time_t
BsonIterDate(BSON_ITERATOR *it)
{
	return bson_iter_date_time(it);
}

const char *
BsonIterKey(BSON_ITERATOR *it)
{
	return bson_iter_key(it);
}

int
BsonIterType(BSON_ITERATOR *it)
{
	return bson_iter_type(it);
}

int
BsonIterNext(BSON_ITERATOR *it)
{
	return bson_iter_next(it);
}

bool
BsonIterSubIter(BSON_ITERATOR *it, BSON_ITERATOR *sub)
{
	return bson_iter_recurse(it, sub);
}

void
BsonOidFromString(bson_oid_t *o, char *str)
{
	bson_oid_init_from_string(o, str);
}

bool
BsonAppendOid(BSON *b, const char *key, bson_oid_t *v)
{
	return bson_append_oid(b, key, strlen(key), v);
}

bool
BsonAppendBool(BSON *b, const char *key, bool v)
{
	return bson_append_bool(b, key, -1, v);
}

bool
BsonAppendStartObject(BSON *b, char *key, BSON *r)
{
	return bson_append_document_begin(b, key, strlen(key), r);
}

bool
BsonAppendFinishObject(BSON *b, BSON *r)
{
	return bson_append_document_end(b, r);
}

bool
BsonAppendNull(BSON *b, const char *key)
{
	return bson_append_null(b, key, strlen(key));
}

bool
BsonAppendInt32(BSON *b, const char *key, int v)
{
	return bson_append_int32(b, key, strlen(key), v);
}

bool
BsonAppendInt64(BSON *b, const char *key, int64_t v)
{
	return bson_append_int64(b, key, strlen(key), v);
}

bool
BsonAppendDouble(BSON *b, const char *key, double v)
{
	return bson_append_double(b, key, strlen(key), v);
}

bool
BsonAppendUTF8(BSON *b, const char *key, char *v)
{

	return bson_append_utf8(b, key, strlen(key), v, strlen(v));
}

bool
BsonAppendBinary(BSON *b, const char *key, char *v, size_t len)
{
	return bson_append_binary(b, key, (int) strlen(key), BSON_SUBTYPE_BINARY,
							  (const uint8_t *) v, len);
}

bool
BsonAppendDate(BSON *b, const char *key, time_t v)
{
	return bson_append_date_time(b, key, strlen(key), v);
}

bool
BsonAppendBson(BSON *b, char *key, BSON *c)
{
	return bson_append_document(b, key, strlen(key), c);
}

bool
BsonAppendStartArray(BSON *b, const char *key, BSON *c)
{
	return bson_append_array_begin(b, key, -1, c);
}

bool
BsonAppendFinishArray(BSON *b, BSON *c)
{
	return bson_append_array_end(b, c);
}

bool
BsonFinish(BSON *b)
{
	/*
	 * There is no need for bson_finish in Meta Driver.  We are doing nothing,
	 * just because of compatibility with legacy driver.
	 */
	return true;
}

bool
JsonToBsonAppendElement(BSON *bb, const char *k, struct json_object *v)
{
	bool		status = true;

	if (!v)
	{
		BsonAppendNull(bb, k);
		return status;
	}

	switch (json_object_get_type(v))
	{
		case json_type_int:
			BsonAppendInt32(bb, k, json_object_get_int(v));
			break;
		case json_type_boolean:
			BsonAppendBool(bb, k, json_object_get_boolean(v));
			break;
		case json_type_double:
			BsonAppendDouble(bb, k, json_object_get_double(v));
			break;
		case json_type_string:
			BsonAppendUTF8(bb, k, (char *) json_object_get_string(v));
			break;
		case json_type_object:
			{
				BSON		t;
				struct json_object *joj;

				joj = json_object_object_get(v, "$oid");

				if (joj != NULL)
				{
					bson_oid_t	bsonObjectId;

					memset(bsonObjectId.bytes, 0, sizeof(bsonObjectId.bytes));
					BsonOidFromString(&bsonObjectId, (char *) json_object_get_string(joj));
					status = BsonAppendOid(bb, k, &bsonObjectId);
					break;
				}
				joj = json_object_object_get(v, "$date");
				if (joj != NULL)
				{
					status = BsonAppendDate(bb, k, json_object_get_int64(joj));
					break;
				}
				BsonAppendStartObject(bb, (char *) k, &t);

				{
					json_object_object_foreach(v, kk, vv)
						JsonToBsonAppendElement(&t, kk, vv);
				}
				BsonAppendFinishObject(bb, &t);
			}
			break;
		case json_type_array:
			{
				int			i;
				char		buf[10];
				BSON		t;

				BsonAppendStartArray(bb, k, &t);
				for (i = 0; i < json_object_array_length(v); i++)
				{
					sprintf(buf, "%d", i);
					JsonToBsonAppendElement(&t, buf, json_object_array_get_idx(v, i));
				}
				BsonAppendFinishObject(bb, &t);
			}
			break;
		default:
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_DATA_TYPE),
					 errmsg("can't handle type for : %s",
							json_object_to_json_string(v))));
	}

	return status;
}

json_object *
JsonTokenerPrase(char *s)
{
	return json_tokener_parse(s);
}

/*
 * MongoAggregateCount
 *		Count the number of documents.
 */
double
MongoAggregateCount(MONGO_CONN *conn, const char *database,
					const char *collection, const BSON *b)
{
	BSON	   *command;
	BSON	   *reply;
	double		count = 0;
	mongoc_cursor_t *cursor;

	command = BsonCreate();
	reply = BsonCreate();
	BsonAppendUTF8(command, "count", (char *) collection);
	if (b)						/* Not empty */
		BsonAppendBson(command, "query", (BSON *) b);

	BsonFinish(command);

	cursor = mongoc_client_command(conn, database, MONGOC_QUERY_SLAVE_OK, 0, 1,
								   0, command, NULL, NULL);
	if (cursor)
	{
		BSON	   *doc;
		bool		ret;

		ret = mongoc_cursor_next(cursor, (const BSON **) &doc);
		if (ret)
		{
			bson_iter_t it;

			bson_copy_to(doc, reply);
			if (bson_iter_init_find(&it, reply, "n"))
				count = BsonIterDouble(&it);
		}
		mongoc_cursor_destroy(cursor);
	}
	BsonDestroy(reply);
	BsonDestroy(command);

	return count;
}

void
BsonOidToString(const bson_oid_t *o, char str[25])
{
	bson_oid_to_string(o, str);
}

const char *
BsonIterCode(BSON_ITERATOR *i)
{
	return bson_iter_code(i, NULL);
}

const char *
BsonIterRegex(BSON_ITERATOR *i)
{
	return bson_iter_regex(i, NULL);
}

const bson_value_t *
BsonIterValue(BSON_ITERATOR *i)
{
	return bson_iter_value(i);
}

void
BsonToJsonStringValue(StringInfo output, BSON_ITERATOR *iter, bool isArray)
{
	if (isArray)
		DumpJsonArray(output, iter);
	else
		DumpJsonObject(output, iter);
}

/*
 * DumpJsonObject
 *		Converts BSON document to a JSON string.
 *
 * isArray signifies if bsonData is contents of array or object.
 * [Some of] special BSON datatypes are converted to JSON using
 * "Strict MongoDB Extended JSON" [1].
 *
 * [1] http://docs.mongodb.org/manual/reference/mongodb-extended-json/
 */
void
DumpJsonObject(StringInfo output, BSON_ITERATOR *iter)
{
	uint32_t	len;
	const uint8_t *data;
	BSON 		bson;

	bson_iter_document(iter, &len, &data);
	if (bson_init_static(&bson, data, len))
	{
		char	   *json = bson_as_json(&bson, NULL);

		if (json != NULL)
		{
			appendStringInfoString(output, json);
			bson_free(json);
		}
	}
}

void
DumpJsonArray(StringInfo output, BSON_ITERATOR *iter)
{
	uint32_t	len;
	const uint8_t *data;
	BSON 		bson;

	bson_iter_array(iter, &len, &data);
	if (bson_init_static(&bson, data, len))
	{
		char	   *json;

		if ((json = bson_array_as_json(&bson, NULL)))
		{
			appendStringInfoString(output, json);
			bson_free(json);
		}
	}
}

char *
BsonAsJson(const BSON *bsonDocument)
{
	return bson_as_json(bsonDocument, NULL);
}
