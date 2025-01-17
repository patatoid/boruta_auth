defmodule Boruta.Did do
  # TODO integration tests
  @moduledoc """
    Utilities to manipulate dids using an universal resolver or registrar.
  """

  import Boruta.Config,
    only: [
      universal_did_auth: 0,
      ebsi_did_resolver_base_url: 0,
      did_resolver_base_url: 0,
      did_registrar_base_url: 0
    ]

  @spec resolve(did :: String.t()) ::
          {:ok, did_document :: map()} | {:error, reason :: String.t()}
  def resolve("did:ebsi" <> _key = did) do
    resolver_url = "#{ebsi_did_resolver_base_url()}/identifiers/#{did}"

    case Finch.build(:get, resolver_url)
           |> Finch.request(OpenIDHttpClient) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        case Jason.decode(body) do
          {:ok, %{"didDocument" => did_document}} ->
            {:ok, did_document}
          {:ok, did_document} ->
            {:ok, did_document}
          {:error, error} ->
            {:error, error}
        end

      {:ok, %Finch.Response{body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  def resolve(did) do
    resolver_url = "#{did_resolver_base_url()}/identifiers/#{did}"

    with {:ok, %Finch.Response{body: body, status: 200}} <- Finch.build(:get, resolver_url, [
           {"Authorization", "Bearer #{universal_did_auth()[:token]}"}
         ])
         |> Finch.request(OpenIDHttpClient),
         {:ok, %{"didDocument" => did_document}} <- Jason.decode(body) do
      {:ok, did_document}

    else
      {:ok, %Finch.Response{body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, inspect(error)}
      {:ok, response} ->
        {:error, "Invalid resolver response: \"#{inspect(response)}\""}
    end
  end

  @spec create(method :: String.t(), jwk :: map()) ::
          {:ok, did :: String.t()} | {:error, reason :: String.t()}
  def create(method, jwk) do
    payload = %{
      "didDocument" => %{
        "@context" => ["https//www.w3.org/ns/did/v1"],
        "service" => [],
        "verificationMethod" => [
          %{
            "id" => "#temp",
            "type" => "JsonWebKey2020",
            "publicKeyJwk" => jwk
          }
        ]
      },
      "options" => %{
        "keyType" => "Ed25519",
        "clientSecretMode" => true,
        "jwkJcsPub" => true
      },
      "secret" => %{}
    }

    case Finch.build(
           :post,
           did_registrar_base_url() <> "/create?method=#{method}",
           [
             {"Authorization", "Bearer #{universal_did_auth()[:token]}"},
             {"Content-Type", "application/json"}
           ],
           Jason.encode!(payload)
         )
         |> Finch.request(OpenIDHttpClient) do
      {:ok, %Finch.Response{status: 201, body: body}} ->
        %{"didState" => %{"did" => did}} = Jason.decode!(body)
        {:ok, did}

      _ ->
        {:error, "Could not create did."}
    end
  end
end
