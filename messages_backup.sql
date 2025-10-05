--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id uuid NOT NULL,
    sender_name character varying(255) NOT NULL,
    timestamp_ms bigint NOT NULL,
    content text,
    photos jsonb,
    videos jsonb,
    audio jsonb,
    reactions jsonb,
    is_geoblocked_for_viewer boolean DEFAULT false,
    is_unsent_image_by_messenger_kid_parent boolean DEFAULT false,
    delivered boolean DEFAULT true,
    read boolean DEFAULT false,
    reply_to uuid,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: messages messages_id_created_at_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_id_created_at_unique UNIQUE (id, created_at);


--
-- Name: messages unique_id_created_at; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT unique_id_created_at UNIQUE (id, created_at);


--
-- Name: messages_content_fts_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX messages_content_fts_idx ON ONLY public.messages USING gin (to_tsvector('english'::regconfig, content));


--
-- Name: messages_photos_gin_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX messages_photos_gin_idx ON ONLY public.messages USING gin (photos);


--
-- Name: messages_reactions_gin_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX messages_reactions_gin_idx ON ONLY public.messages USING gin (reactions);


--
-- Name: messages_sender_name_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX messages_sender_name_idx ON ONLY public.messages USING btree (sender_name);


--
-- Name: messages_timestamp_ms_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX messages_timestamp_ms_idx ON ONLY public.messages USING btree (timestamp_ms DESC);


--
-- Name: messages messages_reply_to_created_at_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.messages
    ADD CONSTRAINT messages_reply_to_created_at_fkey FOREIGN KEY (reply_to, created_at) REFERENCES public.messages(id, created_at);


--
-- PostgreSQL database dump complete
--

