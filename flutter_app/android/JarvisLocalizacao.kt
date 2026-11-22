package com.jarvis.nova

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Localização do aparelho pelo `LocationManager` do próprio Android.
 *
 * Não usa serviço de mapas nem envia coordenadas para a nuvem. O endereço
 * aproximado, quando existe, vem do `Geocoder` do aparelho e é marcado como
 * aproximado; se o Android não conseguir resolver, a resposta traz só as
 * coordenadas, com precisão e idade em metros/segundos — nada é inventado.
 *
 * A leitura só acontece quando o usuário pede (tela ou comando) e só com a
 * permissão de localização concedida.
 */
object JarvisLocalizacao {
    const val PERMISSAO_FINA = Manifest.permission.ACCESS_FINE_LOCATION
    const val PERMISSAO_GROSSA = Manifest.permission.ACCESS_COARSE_LOCATION

    /** Tempo máximo esperando um ponto novo antes de responder com o último conhecido. */
    private const val LIMITE_MS = 20_000L

    fun temPermissao(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, PERMISSAO_FINA) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, PERMISSAO_GROSSA) ==
            PackageManager.PERMISSION_GRANTED

    private fun gerenciador(context: Context): LocationManager? =
        context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private fun ligado(gerenciador: LocationManager, provedor: String): Boolean = try {
        gerenciador.isProviderEnabled(provedor)
    } catch (_: Exception) {
        false
    }

    fun estado(context: Context): Map<String, Any> {
        val gerenciador = gerenciador(context)
        val gps = gerenciador != null && ligado(gerenciador, LocationManager.GPS_PROVIDER)
        val rede = gerenciador != null && ligado(gerenciador, LocationManager.NETWORK_PROVIDER)
        return mapOf(
            "permissao" to temPermissao(context),
            "gpsLigado" to gps,
            "redeLigada" to rede,
            "algumLigado" to (gps || rede),
            "geocoder" to Geocoder.isPresent(),
        )
    }

    private fun melhorConhecido(gerenciador: LocationManager): Location? {
        val candidatos = mutableListOf<Location>()
        for (provedor in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            if (!ligado(gerenciador, provedor)) continue
            try {
                gerenciador.getLastKnownLocation(provedor)?.let { candidatos.add(it) }
            } catch (_: SecurityException) {
            } catch (_: Exception) {
            }
        }
        return candidatos.maxByOrNull { it.time }
    }

    /** Responde com coordenadas, precisão, fonte, idade e (quando possível) endereço. */
    fun obter(context: Context, result: MethodChannel.Result) {
        if (!temPermissao(context)) {
            result.success(
                mapOf(
                    "ok" to false,
                    "precisaPermissao" to true,
                    "mensagem" to
                        "Sem a permissão de localização eu não vejo onde o aparelho está. " +
                        "Autorize em Central do aparelho → Localização."
                )
            )
            return
        }
        val gerenciador = gerenciador(context)
        if (gerenciador == null) {
            result.success(mapOf("ok" to false, "mensagem" to "Este aparelho não informou o serviço de localização."))
            return
        }
        val gps = ligado(gerenciador, LocationManager.GPS_PROVIDER)
        val rede = ligado(gerenciador, LocationManager.NETWORK_PROVIDER)
        if (!gps && !rede) {
            result.success(
                mapOf(
                    "ok" to false,
                    "mensagem" to
                        "A localização do aparelho está desligada. Ative o GPS em " +
                        "Configurações → Localização e tente de novo."
                )
            )
            return
        }
        val ultimo = melhorConhecido(gerenciador)
        val agora = System.currentTimeMillis()
        if (ultimo != null && agora - ultimo.time <= 60_000L) {
            entregar(context, result, ultimo, "ultima_conhecida")
            return
        }

        val provedor = if (gps) LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
        val handler = Handler(Looper.getMainLooper())
        var entregue = false
        var inscrito: android.location.LocationListener? = null

        fun concluir(local: Location?, fonte: String, aviso: String) {
            if (entregue) return
            entregue = true
            try {
                inscrito?.let { gerenciador.removeUpdates(it) }
            } catch (_: Exception) {
            }
            handler.removeCallbacksAndMessages(null)
            if (local != null) {
                entregar(context, result, local, fonte, aviso)
            } else {
                result.success(mapOf("ok" to false, "mensagem" to aviso))
            }
        }

        val listener = object : android.location.LocationListener {
            override fun onLocationChanged(local: Location) {
                concluir(local, "nova_leitura", "")
            }

            override fun onProviderDisabled(provedorDesligado: String) {
                concluir(
                    melhorConhecido(gerenciador),
                    "ultima_conhecida",
                    "O provedor de localização foi desligado durante a leitura."
                )
            }

            override fun onProviderEnabled(provedorLigado: String) = Unit
            override fun onStatusChanged(provedor: String?, status: Int, extras: android.os.Bundle?) = Unit
        }

        inscrito = listener
        try {
            gerenciador.requestLocationUpdates(provedor, 0L, 0f, listener, Looper.getMainLooper())
        } catch (erro: SecurityException) {
            result.success(
                mapOf("ok" to false, "precisaPermissao" to true, "mensagem" to "O Android recusou a localização sem permissão.")
            )
            return
        } catch (erro: Exception) {
            result.success(
                mapOf(
                    "ok" to false,
                    "mensagem" to "O Android recusou a leitura de localização: ${erro.message ?: erro.javaClass.simpleName}"
                )
            )
            return
        }

        handler.postDelayed({
            if (entregue) return@postDelayed
            val conhecido = melhorConhecido(gerenciador)
            if (conhecido != null) {
                concluir(
                    conhecido,
                    "ultima_conhecida",
                    "Não veio um ponto novo em 20 segundos; usei o último conhecido."
                )
            } else {
                concluir(
                    null,
                    "",
                    "Nenhum ponto de localização chegou em 20 segundos. Vá para um lugar aberto e tente de novo."
                )
            }
        }, LIMITE_MS)
    }

    private fun entregar(
        context: Context,
        result: MethodChannel.Result,
        local: Location,
        fonte: String,
        aviso: String = "",
    ) {
        // O Geocoder pode ir à rede por conta do Android: roda fora da thread principal.
        Thread {
            val endereco = endereco(context, local.latitude, local.longitude)
            Handler(Looper.getMainLooper()).post {
                result.success(
                    mapOf(
                        "ok" to true,
                        "latitude" to local.latitude,
                        "longitude" to local.longitude,
                        "precisaoMetros" to if (local.hasAccuracy()) local.accuracy.toDouble() else 0.0,
                        "fonte" to fonte,
                        "provedor" to (local.provider ?: ""),
                        "idadeMs" to (System.currentTimeMillis() - local.time).coerceAtLeast(0L),
                        "endereco" to endereco,
                        "aviso" to aviso,
                        "mensagem" to "Localização lida do aparelho.",
                    )
                )
            }
        }.start()
    }

    /** Endereço aproximado do próprio Android; vazio quando indisponível. */
    @Suppress("DEPRECATION")
    private fun endereco(context: Context, latitude: Double, longitude: Double): String {
        if (!Geocoder.isPresent()) return ""
        return try {
            val geocoder = Geocoder(context, Locale("pt", "BR"))
            val achado = geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
                ?: return ""
            val partes = listOfNotNull(
                achado.thoroughfare,
                achado.subLocality,
                achado.locality,
                achado.adminArea,
                achado.countryName,
            ).filter { it.isNotBlank() }.distinct()
            partes.joinToString(", ")
        } catch (_: Exception) {
            ""
        }
    }
}
