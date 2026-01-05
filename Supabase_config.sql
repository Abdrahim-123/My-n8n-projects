-- 1. Enable the Vector Extension
-- This allows Supabase to understand AI math (embeddings).
create extension if not exists vector;

----------------------------------------------------------------
-- TABLE 1: TICKETS (The Bot's Short-Term Memory)
-- Stores past conversations to detect duplicates.
----------------------------------------------------------------
create table if not exists tickets (
  id bigint primary key generated always as identity,
  content text,                     -- The user's email text
  category text,                    -- Bug, Question, etc.
  urgency int,                      -- Score 1-10
  sentiment text,                   -- Positive/Negative
  draft_reply text,                 -- The AI's generated answer
  created_at timestamptz default now(),
  embedding vector(768)             -- 768 dim vector (matches HuggingFace model)
);

-- Search Function for Tickets (Duplicate Detector)
create or replace function match_tickets (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns table (
  id bigint,
  content text,
  draft_reply text,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    tickets.id,
    tickets.content,
    tickets.draft_reply,
    1 - (tickets.embedding <=> query_embedding) as similarity
  from tickets
  where 1 - (tickets.embedding <=> query_embedding) > match_threshold
  order by tickets.embedding <=> query_embedding
  limit match_count;
end;
$$;

----------------------------------------------------------------
-- TABLE 2: DOCUMENTS (The Bot's Knowledge Base)
-- Stores company policies for RAG (Retrieval Augmented Generation).
----------------------------------------------------------------
create table if not exists documents (
  id bigint primary key generated always as identity,
  content text,                     -- The policy text chunk
  metadata jsonb,                   -- Info like filename, page number
  embedding vector(768)             -- 768 dim vector
);

-- Search Function for Documents (The Librarian)
create or replace function match_documents (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where 1 - (documents.embedding <=> query_embedding) > match_threshold
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

----------------------------------------------------------------
-- SUCCESS!
-- Run this script, and your database is ready for the AI Agent.
----------------------------------------------------------------