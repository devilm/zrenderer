module zrenderer.server.routes.render;

import config;
import std.datetime : seconds;
import std.typecons : Nullable;
import validation : isEffectArgValid, isJobArgValid, isCanvasArgValid,
    isTextureArgValid;
import vibe.core.concurrency : send, receiveTimeout, OwnerTerminated;
import vibe.core.core : runWorkerTaskH;
import vibe.core.task : Task;
import vibe.data.json;
import vibe.data.serialization;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import zrenderer.server.auth : AccessToken, checkAuth;
import zrenderer.server.dto : RenderRequestData, RenderResponseData, toString;
import zrenderer.server.globals : defaultConfig, accessTokens;
import zrenderer.server.routes : setErrorResponse, mergeStruct, logCustomRequest;
import zrenderer.server.worker : RenderWorkerRequest, RenderWorkerResult, renderWorker;

void handleRenderRequest(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    auto accessToken = checkAuth(req, accessTokens);
    if (!accessToken.isNull && !accessToken.get.isValid)
    {
        accessToken = Nullable!AccessToken.init;
    }

    if (req.json == Json.undefined)
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Expected json input");
        return;
    }

    RenderRequestData requestData;

    try
    {
        requestData = deserializeJson!RenderRequestData(req.json);
    }
    catch (Exception err)
    {
        setErrorResponse(res, HTTPStatus.badRequest, err.msg);
        return;
    }

    logCustomRequest(req, requestData.toString, accessToken);

    Config mergedConfig = mergeStruct(defaultConfig, requestData);

    const maxJobIdsPerRequest = accessToken.isNull
        ? -1
        : accessToken.get.properties.maxJobIdsPerRequest;
    if (!isJobArgValid(mergedConfig.job, maxJobIdsPerRequest))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid job element");
        return;
    }

    if (!isCanvasArgValid(mergedConfig.canvas))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid canvas element");
        return;
    }

    if (!isEffectArgValid(mergedConfig.effect))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid effect element");
        return;
    }

    if (!isTextureArgValid(mergedConfig.texture))
    {
        setErrorResponse(res, HTTPStatus.badRequest, "Invalid texture element");
        return;
    }

    import std.exception : ifThrown;

    bool downloadImage = (req.query["downloadimage"].length >= 0).ifThrown(false);
    bool encodeResponse = mergedConfig.outputFormat == OutputFormat.zip || downloadImage;
    if (encodeResponse)
    {
        mergedConfig.returnExistingFiles = false;
    }

    auto worker = runWorkerTaskH(&renderWorker, Task.getThis);
    send(worker, RenderWorkerRequest(cast(immutable Config) mergedConfig, encodeResponse));

    RenderResponseData response;
    ubyte[] responseBody;
    bool renderingSucceeded = false;

    try
    {
        receiveTimeout(5.seconds,
                (RenderWorkerResult result) {
                    response.output = result.output;
                    responseBody = cast(ubyte[]) result.body;
                    renderingSucceeded = true;
                },
                (bool failed) {
                    renderingSucceeded = !failed;
                }
        );
    }
    catch (OwnerTerminated e)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Rendering timed out / was aborted");
        return;
    }

    if (!renderingSucceeded)
    {
        setErrorResponse(res, HTTPStatus.internalServerError, "Error during rendering process");
        return;
    }

    if (mergedConfig.outputFormat == OutputFormat.zip)
    {

        if (response.output.length == 0)
        {
            setErrorResponse(res, HTTPStatus.noContent, "Nothing rendered");
            return;
        }

        res.contentType("application/zip");
        res.writeBody(cast(ubyte[]) responseBody);
    }
    else
    {
        if (downloadImage)
        {
            if (response.output.length == 0)
            {
                setErrorResponse(res, HTTPStatus.noContent, "Nothing rendered");
                return;
            }

            res.contentType("image/png");
            res.writeBody(cast(ubyte[]) responseBody);
        }
        else
        {
            res.writeJsonBody(serializeToJson(response));
        }
    }
}
