---+++ Feed Manager

-- feed.blog.attach
-- feed.blog.detach
-- feed.blog.sync


--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2008 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds_setting_set" (
  inout settings any,
  inout options any,
  in settingName varchar)
{
  ENEWS.WA.set_keyword (settingName, settings, get_keyword (settingName, options, get_keyword (settingName, settings)));
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds_setting_xml" (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.get" (
  in feed_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, f_id integer;
  declare uname varchar;
  declare q, iri varchar;

  inst_id := (select EFD_DOMAIN_ID from ENEWS.WA.FEED_DOMAIN where EFD_ID = feed_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  f_id := (select EFD_FEED_ID from ENEWS.WA.FEED_DOMAIN where EFD_ID = feed_id);
  iri := SIOC..feed_iri (f_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.subscribe" (
  in inst_id integer,
  in uri varchar,
  in name varchar := null,
  in homeUri varchar := null,
  in tags varchar := null,
  in folder_id integer := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, f_id, feed_id integer;
  declare uname varchar;
  declare channels any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  channels := ENEWS.WA.channels_uri (uri);
  if ((not length (channels)) or (channels[0] <> 'channel'))
    signal ('FM103', 'Bad subscription source!');
  f_id := ENEWS.WA.channel_create (channels[1]);
  feed_id := ENEWS.WA.channel_domain (-1, inst_id, f_id, coalesce (name, get_keyword ('title', channels[1])), tags, '', folder_id);
  commit work;

  if (not ENEWS.WA.channel_feeds (f_id))
  {
    declare continue handler for sqlstate '*' {
      goto _next;
    };
    ENEWS.WA.feed_refresh (f_id);
  }

_next:
  return ods_serialize_int_res (feed_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.unsubscribe" (
  in feed_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id integer;
  declare rc integer;
  declare uname varchar;

  inst_id := (select EFD_DOMAIN_ID from ENEWS.WA.FEED_DOMAIN where EFD_ID = feed_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  ENEWS.WA.channel_delete (feed_id);
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.refresh" (
  in feed_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, f_id integer;
  declare rc integer;
  declare uname varchar;

  inst_id := (select EFD_DOMAIN_ID from ENEWS.WA.FEED_DOMAIN where EFD_ID = feed_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  f_id := (select EFD_FEED_ID from ENEWS.WA.FEED_DOMAIN where EFD_ID = feed_id);
  ENEWS.WA.feed_refresh (f_id);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.folder.new" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  rc := ENEWS.WA.folder_id (inst_id, path);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.folder.delete" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare folder_id integer;
  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  folder_id := ENEWS.WA.folder_id (inst_id, path);
  if (isnull (folder_id))
    return ods_serialize_int_res (0);

  ENEWS.WA.folder_delete (inst_id, folder_id);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.comment.get" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id, item_id integer;
  declare q, iri varchar;

  whenever not found goto _exit;

  select EFIC_DOMAIN_ID, EFIC_ITEM_ID into inst_id, item_id from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  iri := SIOC..feed_comment_iri (inst_id, cast (item_id as integer), comment_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);

_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.comment.new" (
  in inst_id integer,
  in item_id integer,
  in parent_id integer := null,
  in title varchar,
  in text varchar,
  in name varchar,
  in email varchar,
  in url varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  rc := -1;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (not (ENEWS.WA.discussion_check () and ENEWS.WA.conversation_enable (inst_id)))
    return signal('API01', 'Discussions must be enabled for this instance');

  if (isnull (parent_id))
  {
    -- get root comment;
    parent_id := (select EFIC_ID from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = inst_id and EFIC_ITEM_ID = item_id and EFIC_PARENT_ID is null);
    if (isnull (parent_id))
    {
      ENEWS.WA.nntp_root (inst_id, item_id);
      parent_id := (select EFIC_ID from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = inst_id and EFIC_ITEM_ID = item_id and EFIC_PARENT_ID is null);
    }
  }

  ENEWS.WA.nntp_update_item (inst_id, item_id);
  insert into ENEWS.WA.FEED_ITEM_COMMENT (EFIC_PARENT_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_U_URL, EFIC_LAST_UPDATE)
    values (parent_id, inst_id, item_id, title, text, name, email, url, now ());
  rc := (select max (EFIC_ID) from ENEWS.WA.FEED_ITEM_COMMENT);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.comment.delete" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select EFIC_DOMAIN_ID from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ID = comment_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  delete from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.blog.subscribe" (
  in inst_id integer,
  in name varchar,
  in api varchar,
  in uri varchar,
  in port varchar,
  in endpoint varchar,
  in "user" varchar,
  in "password" varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare weblog_id integer;
  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  weblog_id := ENEWS.WA.weblog_update (-1, inst_id, 'Weblog - ' || "user", api, uri, port, endpoint, "user", "password");
  ENEWS.WA.weblog_refresh (weblog_id, name);
  rc := (select EB_ID from ENEWS.WA.BLOG where EB_WEBLOG_ID = weblog_id and EB_NAME = name);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.blog.unsubscribe" (
  in blog_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id integer;
  declare rc integer;
  declare uname varchar;

  inst_id := (select EW_DOMAIN_ID from ENEWS.WA.WEBLOG, ENEWS.WA.BLOG where EW_ID = EB_WEBLOG_ID and EB_ID = blog_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  ENEWS.WA.blog_delete (blog_id);
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.blog.refresh" (
  in blog_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id integer;
  declare rc integer;
  declare uname varchar;

  inst_id := (select EW_DOMAIN_ID from ENEWS.WA.WEBLOG, ENEWS.WA.BLOG where EW_ID = EB_WEBLOG_ID and EB_ID = blog_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  ENEWS.WA.blog_refresh (blog_id);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.options.set" (
  in inst_id int, in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := ENEWS.WA.settings (inst_id, account_id);
  ENEWS.WA.settings_init (settings);

  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'favourites');
  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'rows');
  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'atomVersion');

  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'updateFeeds');
  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'updateBlogs');
  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'feedIcons');

  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'conv');
  ODS.ODS_API.feeds_setting_set (settings, optionsParams, 'conv_init');

  insert replacing ENEWS.WA.SETTINGS (ES_DOMAIN_ID, ES_ACCOUNT_ID, ES_DATA)
    values (inst_id, account_id, serialize (settings));

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."feeds.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare uname varchar;
  declare settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);

  settings := ENEWS.WA.settings (inst_id, account_id);
  ENEWS.WA.settings_init (settings);

  http ('<settings>');

  http (ODS.ODS_API.feeds_setting_xml (settings, 'favourites'));
  http (ODS.ODS_API.feeds_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.feeds_setting_xml (settings, 'atomVersion'));

  http (ODS.ODS_API.feeds_setting_xml (settings, 'updateFeeds'));
  http (ODS.ODS_API.feeds_setting_xml (settings, 'updateBlogs'));
  http (ODS.ODS_API.feeds_setting_xml (settings, 'feedIcons'));

  http (ODS.ODS_API.feeds_setting_xml (settings, 'conv'));
  http (ODS.ODS_API.feeds_setting_xml (settings, 'conv_init'));

  http ('</settings>');

  return '';
}
;

grant execute on ODS.ODS_API."feeds.get" to ODS_API;
grant execute on ODS.ODS_API."feeds.subscribe" to ODS_API;
grant execute on ODS.ODS_API."feeds.unsubscribe" to ODS_API;
grant execute on ODS.ODS_API."feeds.refresh" to ODS_API;
grant execute on ODS.ODS_API."feeds.folder.new" to ODS_API;
grant execute on ODS.ODS_API."feeds.folder.delete" to ODS_API;
grant execute on ODS.ODS_API."feeds.comment.get" to ODS_API;
grant execute on ODS.ODS_API."feeds.comment.new" to ODS_API;
grant execute on ODS.ODS_API."feeds.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."feeds.blog.subscribe" to ODS_API;
grant execute on ODS.ODS_API."feeds.blog.unsubscribe" to ODS_API;
grant execute on ODS.ODS_API."feeds.blog.refresh" to ODS_API;

grant execute on ODS.ODS_API."feeds.options.get" to ODS_API;
grant execute on ODS.ODS_API."feeds.options.set" to ODS_API;

use DB;